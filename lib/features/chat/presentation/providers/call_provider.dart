import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/data/datasources/call_room_service.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

/// A participant as the call screen needs them: identity, their audio/video
/// tracks and whether they are talking.
///
/// LiveKit identifies participants by an opaque `identity` string, while the
/// chat API speaks numeric `user_id` (api-docs §6.3). [userId] is that string
/// parsed back to an int so a tile can be matched against a chat member — it is
/// `null` when the identity isn't a plain id, which is why the mute-others
/// control is hidden for such a tile rather than pointed at a guessed user.
class CallParticipant extends Equatable {
  final String identity;
  final int? userId;
  final String? name;
  final bool isLocal;
  final bool isSpeaking;
  final bool isMicrophoneEnabled;
  final bool isCameraEnabled;
  final VideoTrack? videoTrack;

  const CallParticipant({
    required this.identity,
    required this.userId,
    required this.name,
    required this.isLocal,
    required this.isSpeaking,
    required this.isMicrophoneEnabled,
    required this.isCameraEnabled,
    required this.videoTrack,
  });

  @override
  List<Object?> get props => [
    identity,
    userId,
    name,
    isLocal,
    isSpeaking,
    isMicrophoneEnabled,
    isCameraEnabled,
    videoTrack,
  ];
}

/// Where the call is in its lifecycle.
///
/// [connecting] covers **both** network legs — the `POST /calls/join/` request
/// and the LiveKit handshake — because the user cannot act differently during
/// either, and splitting them would only add a spinner variant.
enum CallStage { idle, connecting, connected, disconnected }

class CallState extends Equatable {
  final CallStage stage;

  /// The §6.6 `JoinTokenDTO`. Retained after connecting so the room slug can
  /// be shown and a reconnect doesn't need a second rate-limited join
  /// (10 per 5 min).
  final CallTokenEntity? token;

  final List<CallParticipant> participants;
  final bool isMicrophoneEnabled;
  final bool isCameraEnabled;
  final Failure? failure;

  const CallState({
    this.stage = CallStage.idle,
    this.token,
    this.participants = const [],
    this.isMicrophoneEnabled = true,
    this.isCameraEnabled = false,
    this.failure,
  });

  bool get isConnected => stage == CallStage.connected;
  bool get isBusy => stage == CallStage.connecting;

  CallState copyWith({
    CallStage? stage,
    CallTokenEntity? token,
    List<CallParticipant>? participants,
    bool? isMicrophoneEnabled,
    bool? isCameraEnabled,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return CallState(
      stage: stage ?? this.stage,
      token: token ?? this.token,
      participants: participants ?? this.participants,
      isMicrophoneEnabled: isMicrophoneEnabled ?? this.isMicrophoneEnabled,
      isCameraEnabled: isCameraEnabled ?? this.isCameraEnabled,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
    stage,
    token,
    participants,
    isMicrophoneEnabled,
    isCameraEnabled,
    failure,
  ];
}

/// Drives one chat's call: join → connect → roster → leave (api-docs §6.6).
///
/// `AsyncNotifier` like every other controller in the feature, but note the
/// asymmetry: [build] does **not** join. Joining is rate-limited to 10 per
/// 5 minutes and turns the microphone on, so it must be an explicit user
/// action ([join]) rather than a side effect of the screen being built —
/// otherwise a rebuild would silently open a mic.
class CallController extends AsyncNotifier<CallState> {
  CallController(this._chatId);

  /// The chat whose call this drives. Riverpod 3's manual `family` API hands
  /// the argument to the constructor (there is no inherited `arg`).
  final String _chatId;

  StreamSubscription<void>? _roomSubscription;

  @override
  Future<CallState> build() async {
    ref.onDispose(() {
      _roomSubscription?.cancel();
    });
    return const CallState();
  }

  CallRoomService get _service => ref.read(callRoomServiceProvider(_chatId));

  /// `POST /chats/{id}/calls/join/` then `Room.connect`.
  Future<void> join() async {
    final current = state.value ?? const CallState();
    if (current.isBusy || current.isConnected) return;

    state = AsyncData(
      current.copyWith(stage: CallStage.connecting, clearFailure: true),
    );

    final result = await ref.read(joinCallUseCaseProvider).execute(_chatId);

    await result.match(
      (failure) async {
        state = AsyncData(
          current.copyWith(stage: CallStage.idle, failure: failure),
        );
      },
      (token) async {
        final connected = await _service.connect(token);
        connected.match(
          (failure) {
            state = AsyncData(
              current.copyWith(
                stage: CallStage.idle,
                token: token,
                failure: failure,
              ),
            );
          },
          (_) {
            _listenToRoom();
            state = AsyncData(
              current.copyWith(
                stage: CallStage.connected,
                token: token,
                isMicrophoneEnabled: true,
                isCameraEnabled: false,
                clearFailure: true,
              ),
            );
            _syncParticipants();
          },
        );
      },
    );
  }

  Future<void> leave() async {
    await _roomSubscription?.cancel();
    _roomSubscription = null;
    await _service.disconnect();

    final current = state.value ?? const CallState();
    state = AsyncData(
      current.copyWith(
        stage: CallStage.disconnected,
        participants: const [],
        isCameraEnabled: false,
      ),
    );
  }

  Future<void> toggleMicrophone() async {
    final current = state.value;
    if (current == null || !current.isConnected) return;

    final target = !current.isMicrophoneEnabled;
    final result = await _service.setMicrophoneEnabled(target);
    result.match(
      (failure) =>
          state = AsyncData(current.copyWith(failure: failure)),
      (_) => state = AsyncData(
        current.copyWith(isMicrophoneEnabled: target, clearFailure: true),
      ),
    );
    _syncParticipants();
  }

  Future<void> toggleCamera() async {
    final current = state.value;
    if (current == null || !current.isConnected) return;

    final target = !current.isCameraEnabled;
    final result = await _service.setCameraEnabled(target);
    result.match(
      (failure) =>
          state = AsyncData(current.copyWith(failure: failure)),
      (_) => state = AsyncData(
        current.copyWith(isCameraEnabled: target, clearFailure: true),
      ),
    );
    _syncParticipants();
  }

  /// Server-side moderation mute of somebody else (`call:mute_member`, §6.6).
  ///
  /// Deliberately does not touch local state: the server mutes the target's
  /// track, and the resulting `TrackMuted` room event is what updates the
  /// roster — so the UI reflects what actually happened rather than what we
  /// asked for.
  Future<Failure?> muteParticipant(int userId, {bool muted = true}) async {
    final result = await ref
        .read(muteCallParticipantUseCaseProvider)
        .execute(_chatId, userId, muted: muted);

    return result.match((failure) {
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(failure: failure));
      }
      return failure;
    }, (_) => null);
  }

  void _listenToRoom() {
    _roomSubscription?.cancel();
    _roomSubscription = _service.changes.listen((_) => _syncParticipants());
  }

  /// Rebuilds the roster from the SDK's current room state.
  ///
  /// Reading the room on every event (instead of mutating a local list per
  /// event type) keeps this in sync with LiveKit's own bookkeeping — the SDK is
  /// the source of truth for who is present and which tracks are live, and
  /// mirroring it incrementally is how rosters drift.
  void _syncParticipants() {
    final current = state.value;
    if (current == null) return;

    final room = _service.room;
    if (room == null) {
      state = AsyncData(current.copyWith(participants: const []));
      return;
    }

    final participants = <CallParticipant>[];

    final local = room.localParticipant;
    if (local != null) {
      participants.add(_map(local, isLocal: true));
    }
    for (final remote in room.remoteParticipants.values) {
      participants.add(_map(remote, isLocal: false));
    }

    // Local first, then by identity, so tiles don't reshuffle on every
    // speaking/track event.
    participants.sort((a, b) {
      if (a.isLocal != b.isLocal) return a.isLocal ? -1 : 1;
      return a.identity.compareTo(b.identity);
    });

    final mic = local?.isMicrophoneEnabled() ?? current.isMicrophoneEnabled;
    final cam = local?.isCameraEnabled() ?? current.isCameraEnabled;

    state = AsyncData(
      current.copyWith(
        participants: participants,
        isMicrophoneEnabled: mic,
        isCameraEnabled: cam,
      ),
    );
  }

  CallParticipant _map(Participant participant, {required bool isLocal}) {
    VideoTrack? video;
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      // Screen share and camera both land here; either is fine to render, but
      // a muted publication has no live track to paint.
      if (track is VideoTrack && !publication.muted) {
        video = track;
        break;
      }
    }

    return CallParticipant(
      identity: participant.identity,
      userId: int.tryParse(participant.identity),
      name: participant.name.isEmpty ? null : participant.name,
      isLocal: isLocal,
      isSpeaking: participant.isSpeaking,
      isMicrophoneEnabled: participant.isMicrophoneEnabled(),
      isCameraEnabled: participant.isCameraEnabled(),
      videoTrack: video,
    );
  }
}

final callProvider =
    AsyncNotifierProvider.family<CallController, CallState, String>(
      CallController.new,
    );
