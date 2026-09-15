import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/voice_local_store.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/active_call_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

/// Where the waveforms this device recorded and the marks for what it has
/// heard are kept.
final voiceLocalStoreProvider = Provider<VoiceLocalStore>((ref) {
  try {
    return SharedPrefsVoiceLocalStore(ref.watch(localStorageServiceProvider));
  } catch (error) {
    Logger.debug('Voice: no persistent storage, keeping waveforms in memory');
    return InMemoryVoiceLocalStore();
  }
});

/// One voice message, as something that can be played.
class VoiceTrack extends Equatable {
  const VoiceTrack({
    required this.chatId,
    required this.messageId,
    required this.attachment,
  });

  final String chatId;
  final String messageId;
  final AttachmentEntity attachment;

  String get id => attachment.id;

  /// What the server measured, where it has finished measuring. Stands in
  /// for the real duration until the file is open.
  Duration? get declaredDuration {
    final seconds = attachment.durationSeconds;
    if (seconds == null || seconds <= 0) return null;
    return Duration(seconds: seconds);
  }

  @override
  List<Object?> get props => [chatId, messageId, attachment.id];
}

/// Every playable voice message in a feed, in the order it was said.
///
/// The feed itself runs newest first; playback runs the other way, so this
/// reverses it. Slots the gateway has not finished with are left out: they
/// have no bytes to fetch yet, and a queue that stops on one would strand
/// everything after it (api-docs §5.5).
List<VoiceTrack> voiceTracksIn(List<MessageEntity> newestFirst) => [
  for (final message in newestFirst.reversed)
    for (final attachment in message.attachments)
      if (attachment.attachmentType == AttachmentType.voice &&
          attachment.attachmentStatus == AttachmentStatus.success)
        VoiceTrack(
          chatId: message.chatId,
          messageId: message.id,
          attachment: attachment,
        ),
];

/// How fast voice plays back. Three steps, cycled by one button.
enum VoiceSpeed {
  normal(1),
  fast(1.5),
  fastest(2);

  const VoiceSpeed(this.rate);

  final double rate;

  VoiceSpeed get next =>
      VoiceSpeed.values[(index + 1) % VoiceSpeed.values.length];

  /// `1x`, `1.5x`, `2x` — without the trailing `.0`.
  String get label => rate == rate.roundToDouble()
      ? '${rate.toInt()}x'
      : '${rate.toString()}x';
}

class VoicePlaybackState extends Equatable {
  const VoicePlaybackState({
    this.track,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = VoiceSpeed.normal,
    this.failed = false,
    this.listened = const <String>{},
  });

  /// What is loaded. Stays put when paused, so a paused message keeps its
  /// position rather than snapping back to the start.
  final VoiceTrack? track;

  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;

  /// Kept across tracks: somebody who plays voice at double speed means it.
  final VoiceSpeed speed;

  final bool failed;

  /// Attachment ids heard through to the end, on this device.
  final Set<String> listened;

  bool isCurrent(String attachmentId) => track?.id == attachmentId;

  bool isPlayingNow(String attachmentId) =>
      isPlaying && isCurrent(attachmentId);

  bool hasBeenHeard(String attachmentId) => listened.contains(attachmentId);

  /// How far through the loaded track, `[0, 1]`.
  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  VoicePlaybackState copyWith({
    VoiceTrack? track,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    VoiceSpeed? speed,
    bool? failed,
    Set<String>? listened,
    bool clearTrack = false,
  }) => VoicePlaybackState(
    track: clearTrack ? null : (track ?? this.track),
    isPlaying: isPlaying ?? this.isPlaying,
    isLoading: isLoading ?? this.isLoading,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    speed: speed ?? this.speed,
    failed: failed ?? this.failed,
    listened: listened ?? this.listened,
  );

  @override
  List<Object?> get props => [
    track,
    isPlaying,
    isLoading,
    position,
    duration,
    speed,
    failed,
    listened,
  ];
}

/// The one voice message playing anywhere in the app.
///
/// Deliberately app-wide rather than one player per bubble. Three things
/// fall out of that and none of them work otherwise: two voice messages can
/// never talk over each other, playback survives leaving the chat — the
/// player is not in the widget that scrolled away — and when one finishes
/// the next can start.
class VoicePlaybackController extends Notifier<VoicePlaybackState> {
  AudioPlayer? _player;

  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// The voice messages after the one playing, oldest first. Refreshed every
  /// time playback starts, because by then the chat may have more.
  List<VoiceTrack> _upNext = const [];

  /// Set while a call is holding playback down, so leaving the call knows
  /// there is something to pick back up.
  VoiceTrack? _pausedByCall;

  @override
  VoicePlaybackState build() {
    ref.onDispose(() {
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
      _subscriptions.clear();
      unawaited(_player?.dispose());
      _player = null;
    });

    // A call takes the speaker. Playback gets out of the way while one is
    // up and comes back when it ends.
    ref.listen(isCallActiveProvider, (previous, active) {
      if (active) {
        unawaited(_pauseForCall());
      } else {
        unawaited(_resumeAfterCall());
      }
    });

    return VoicePlaybackState(listened: _store.readListened());
  }

  VoiceLocalStore get _store => ref.read(voiceLocalStoreProvider);

  AudioPlayer get _audio {
    final existing = _player;
    if (existing != null) return existing;

    final player = AudioPlayer()..setSpeed(state.speed.rate);
    _player = player;

    _subscriptions.add(
      player.positionStream.listen((position) {
        if (state.track == null) return;
        state = state.copyWith(position: position);
      }),
    );
    _subscriptions.add(
      player.playerStateStream.listen(_onPlayerState),
    );
    _subscriptions.add(
      player.durationStream.listen((duration) {
        if (duration == null || state.track == null) return;
        state = state.copyWith(duration: duration);
      }),
    );

    return player;
  }

  void _onPlayerState(PlayerState playerState) {
    final track = state.track;
    if (track == null) return;

    if (playerState.processingState == ProcessingState.completed) {
      unawaited(_onCompleted(track));
      return;
    }

    state = state.copyWith(
      isPlaying: playerState.playing,
      isLoading:
          playerState.processingState == ProcessingState.loading ||
          playerState.processingState == ProcessingState.buffering,
    );
  }

  /// Starts [track] if it is not the loaded one, otherwise resumes or pauses
  /// what is already there.
  ///
  /// [upNext] is the rest of the chat's voice messages in order, oldest
  /// first — where playback goes when this one ends.
  Future<void> toggle(
    VoiceTrack track, {
    List<VoiceTrack> upNext = const [],
  }) async {
    if (state.isCurrent(track.id) && !state.failed) {
      _upNext = upNext;

      if (state.isPlaying) {
        await _audio.pause();
        return;
      }

      // A finished track replays from the top rather than sitting at its end
      // doing nothing.
      if (state.position >= state.duration && state.duration > Duration.zero) {
        await _audio.seek(Duration.zero);
      }
      await _audio.play();
      return;
    }

    await play(track, upNext: upNext);
  }

  Future<void> play(
    VoiceTrack track, {
    List<VoiceTrack> upNext = const [],
  }) async {
    _upNext = upNext;
    _pausedByCall = null;

    state = state.copyWith(
      track: track,
      isPlaying: false,
      isLoading: true,
      failed: false,
      position: Duration.zero,
      duration: track.declaredDuration ?? Duration.zero,
    );

    // Played from the file, never from `AttachmentDTO.url`: that link is
    // dead after 300 seconds and the cache is keyed by `s3_key` instead
    // (api-docs §5.5). A message played twice is downloaded once.
    final result = await ref
        .read(getAttachmentFileUseCaseProvider)
        .execute(
          chatId: track.chatId,
          messageId: track.messageId,
          attachment: track.attachment,
        );

    final file = result.getRight().toNullable();
    if (file == null) {
      if (state.isCurrent(track.id)) {
        state = state.copyWith(isLoading: false, failed: true);
      }
      return;
    }

    // Somebody started something else while this was downloading.
    if (!state.isCurrent(track.id)) return;

    try {
      final duration = await _audio.setFilePath(file.path);
      if (!state.isCurrent(track.id)) return;

      state = state.copyWith(
        duration: duration ?? track.declaredDuration ?? Duration.zero,
      );
      await _audio.setSpeed(state.speed.rate);

      // Heard, as of now. Waiting for the end would leave the unheard dot on
      // a message somebody listened to most of and then paused, and there is
      // nothing on the server to reconcile it against anyway (api-docs §5.5).
      await _markListened(track.id);

      await _audio.play();
    } on Exception {
      if (state.isCurrent(track.id)) {
        state = state.copyWith(isLoading: false, failed: true);
      }
    }
  }

  Future<void> pause() async {
    if (!state.isPlaying) return;
    await _audio.pause();
  }

  /// Jumps to a fraction of the loaded track — what a tap on the waveform
  /// means.
  Future<void> seekFraction(String attachmentId, double fraction) async {
    if (!state.isCurrent(attachmentId)) return;

    final duration = state.duration;
    if (duration <= Duration.zero) return;

    final target = duration * fraction.clamp(0.0, 1.0);
    state = state.copyWith(position: target);
    await _audio.seek(target);
  }

  /// 1x → 1.5x → 2x → 1x, applied to whatever is playing and to whatever
  /// plays next.
  Future<void> cycleSpeed() async {
    final speed = state.speed.next;
    state = state.copyWith(speed: speed);
    if (_player != null) await _audio.setSpeed(speed.rate);
  }

  Future<void> _onCompleted(VoiceTrack track) async {
    await _markListened(track.id);

    final next = _nextAfter(track);
    if (next == null) {
      state = state.copyWith(
        isPlaying: false,
        isLoading: false,
        position: state.duration,
      );
      return;
    }

    // Run on: a chat that was left with three unplayed voice messages plays
    // all three, the way the sender said them.
    await play(next, upNext: _upNext);
  }

  VoiceTrack? _nextAfter(VoiceTrack track) {
    final index = _upNext.indexWhere((candidate) => candidate.id == track.id);
    if (index < 0 || index + 1 >= _upNext.length) return null;
    return _upNext[index + 1];
  }

  Future<void> _markListened(String attachmentId) async {
    if (state.listened.contains(attachmentId)) return;

    state = state.copyWith(listened: {...state.listened, attachmentId});
    await _store.markListened(attachmentId);
  }

  Future<void> _pauseForCall() async {
    if (!state.isPlaying) return;
    _pausedByCall = state.track;
    await _audio.pause();
  }

  Future<void> _resumeAfterCall() async {
    final track = _pausedByCall;
    _pausedByCall = null;
    if (track == null || !state.isCurrent(track.id)) return;
    await _audio.play();
  }
}

final voicePlaybackProvider =
    NotifierProvider<VoicePlaybackController, VoicePlaybackState>(
      VoicePlaybackController.new,
    );
