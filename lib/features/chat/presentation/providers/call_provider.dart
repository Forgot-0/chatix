import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/permissions/media_permissions.dart';
import 'package:chatix/features/chat/data/datasources/call_room_service.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

/// How good the link between one participant and the LiveKit server is.
///
/// A mirror of `livekit_client`'s own enum so that nothing above this file —
/// the widgets, the tests — has to depend on the SDK to draw a signal bar.
enum CallConnectionQuality { unknown, lost, poor, good, excellent }

/// The two ways a call can be arranged on screen.
///
/// [grid] gives everybody the same amount of room; [speaker] gives almost all
/// of it to one person and leaves the rest in a filmstrip. Which one reads
/// better depends on the call — four people talking versus one presenting —
/// so it is a control on the bar rather than something inferred.
enum CallLayoutMode {
  grid,
  speaker;

  CallLayoutMode get next => this == CallLayoutMode.grid
      ? CallLayoutMode.speaker
      : CallLayoutMode.grid;
}

class CallParticipant extends Equatable {
  final String identity;
  final int? userId;
  final String? name;
  final bool isLocal;
  final bool isSpeaking;

  /// 0…1, as LiveKit last reported it. Drives the size of the speaking ring,
  /// so a tile shows *how* loud somebody is rather than only that they are.
  final double audioLevel;

  final bool isMicrophoneEnabled;
  final bool isCameraEnabled;
  final CallConnectionQuality quality;
  final lk.VideoTrack? videoTrack;

  const CallParticipant({
    required this.identity,
    required this.userId,
    required this.name,
    required this.isLocal,
    required this.isSpeaking,
    required this.isMicrophoneEnabled,
    required this.isCameraEnabled,
    required this.videoTrack,
    this.audioLevel = 0,
    this.quality = CallConnectionQuality.unknown,
  });

  @override
  List<Object?> get props => [
    identity,
    userId,
    name,
    isLocal,
    isSpeaking,
    audioLevel,
    isMicrophoneEnabled,
    isCameraEnabled,
    quality,
    videoTrack,
  ];
}

/// A permission the call asked for and did not get.
///
/// Kept in the state rather than shown once and forgotten: the microphone
/// being off because Android said no is a standing condition of the call, and
/// the bar has to keep saying so until it is fixed.
class CallPermissionIssue extends Equatable {
  const CallPermissionIssue({required this.device, required this.isPermanent});

  final MediaDeviceKind device;

  /// The platform will not prompt again — only the settings app can undo it.
  final bool isPermanent;

  @override
  List<Object?> get props => [device, isPermanent];
}

enum CallStage {
  idle,
  connecting,
  connected,

  /// LiveKit lost the transport and is rebuilding it. The call is not over:
  /// tracks come back on their own if the network does.
  reconnecting,

  /// The room went away without us asking it to.
  disconnected,
}

class CallState extends Equatable {
  final CallStage stage;

  /// Which chat's room this is. Null while nothing is going on.
  final String? chatId;

  /// The chat's name as the joining screen knew it.
  ///
  /// Carried on the state rather than looked up again: the floating mini
  /// player has to name the call from anywhere in the app, and resolving a
  /// chat from an overlay would mean spinning up the whole chat detail — its
  /// socket subscription included — for a single line of text.
  final String? chatName;

  /// When the room came up, for the elapsed-time readout. Null until it does.
  final DateTime? connectedAt;

  final CallTokenEntity? token;

  final List<CallParticipant> participants;
  final bool isMicrophoneEnabled;
  final bool isCameraEnabled;
  final bool isSpeakerphoneEnabled;

  /// False on desktop and web, where there is no earpiece to switch away
  /// from — the speaker control is left off the bar entirely.
  final bool canSwitchSpeaker;

  final CallLayoutMode layout;

  /// Who the speaker layout is pinned to, if the user has tapped somebody.
  final String? pinnedIdentity;

  final Failure? failure;
  final CallPermissionIssue? permissionIssue;

  const CallState({
    this.stage = CallStage.idle,
    this.chatId,
    this.chatName,
    this.connectedAt,
    this.token,
    this.participants = const [],
    this.isMicrophoneEnabled = false,
    this.isCameraEnabled = false,
    this.isSpeakerphoneEnabled = false,
    this.canSwitchSpeaker = false,
    this.layout = CallLayoutMode.grid,
    this.pinnedIdentity,
    this.failure,
    this.permissionIssue,
  });

  bool get isConnected => stage == CallStage.connected;

  bool get isReconnecting => stage == CallStage.reconnecting;

  /// Connected or fighting to get back — either way the room is still ours,
  /// the mini player stays up and leaving means a real disconnect.
  bool get isLive =>
      stage == CallStage.connected || stage == CallStage.reconnecting;

  bool get isBusy => stage == CallStage.connecting;

  /// Whether this state is about [chat] at all — the screen for any other
  /// chat shows its own join prompt rather than somebody else's call.
  bool isFor(String chat) => chatId == chat;

  CallState copyWith({
    CallStage? stage,
    String? chatId,
    String? chatName,
    DateTime? connectedAt,
    CallTokenEntity? token,
    List<CallParticipant>? participants,
    bool? isMicrophoneEnabled,
    bool? isCameraEnabled,
    bool? isSpeakerphoneEnabled,
    bool? canSwitchSpeaker,
    CallLayoutMode? layout,
    String? pinnedIdentity,
    Failure? failure,
    CallPermissionIssue? permissionIssue,
    bool clearFailure = false,
    bool clearPermissionIssue = false,
    bool clearPinned = false,
  }) {
    return CallState(
      stage: stage ?? this.stage,
      chatId: chatId ?? this.chatId,
      chatName: chatName ?? this.chatName,
      connectedAt: connectedAt ?? this.connectedAt,
      token: token ?? this.token,
      participants: participants ?? this.participants,
      isMicrophoneEnabled: isMicrophoneEnabled ?? this.isMicrophoneEnabled,
      isCameraEnabled: isCameraEnabled ?? this.isCameraEnabled,
      isSpeakerphoneEnabled:
          isSpeakerphoneEnabled ?? this.isSpeakerphoneEnabled,
      canSwitchSpeaker: canSwitchSpeaker ?? this.canSwitchSpeaker,
      layout: layout ?? this.layout,
      pinnedIdentity: clearPinned
          ? null
          : (pinnedIdentity ?? this.pinnedIdentity),
      failure: clearFailure ? null : (failure ?? this.failure),
      permissionIssue: clearPermissionIssue
          ? null
          : (permissionIssue ?? this.permissionIssue),
    );
  }

  @override
  List<Object?> get props => [
    stage,
    chatId,
    chatName,
    connectedAt,
    token,
    participants,
    isMicrophoneEnabled,
    isCameraEnabled,
    isSpeakerphoneEnabled,
    canSwitchSpeaker,
    layout,
    pinnedIdentity,
    failure,
    permissionIssue,
  ];
}

/// The one call this device is in, if it is in one.
///
/// App-wide rather than per chat, and deliberately so: the microphone, the
/// speaker and LiveKit's `Room` are single devices, and the floating mini
/// player has to be able to ask "is there a call" without knowing which chat
/// to ask about. Leaving the call screen therefore does not end the call —
/// nothing about the room is tied to the widget tree.
///
/// There is no incoming call here, and cannot be: `call_started`/`call_ended`
/// are declared in `WSEventType` but never published, and there is no push
/// (api-docs §5.6). A call is "join the chat's room", which is what the UI
/// says.
class CallController extends Notifier<CallState> {
  StreamSubscription<CallRoomSignal>? _signals;

  @override
  CallState build() {
    ref.onDispose(() {
      _signals?.cancel();
      _signals = null;
    });
    return const CallState();
  }

  CallRoomService get _service => ref.read(callRoomServiceProvider);

  MediaPermissions get _permissions => ref.read(mediaPermissionsProvider);

  /// Joins (or re-joins) the room behind [chatId].
  ///
  /// Asks for the microphone first, with the join prompt still on screen, so
  /// the platform dialog arrives next to its explanation. A refusal does not
  /// cancel the call: the room is joined muted and the bar keeps saying the
  /// microphone is unavailable, which is more useful than refusing to connect
  /// somebody who only wants to listen.
  Future<void> join(String chatId, {String? chatName}) async {
    if (state.isBusy) return;
    if (state.isLive && state.isFor(chatId)) return;

    if (state.isLive && !state.isFor(chatId)) {
      await leave();
    }

    state = CallState(
      stage: CallStage.connecting,
      chatId: chatId,
      chatName: chatName,
      layout: state.layout,
    );

    final microphone = await _permissions.request(MediaDeviceKind.microphone);
    final permissionIssue = microphone.isGranted
        ? null
        : CallPermissionIssue(
            device: MediaDeviceKind.microphone,
            isPermanent: microphone.needsSettings,
          );

    // The user may have hung up while the prompt was on screen.
    if (state.stage != CallStage.connecting || !state.isFor(chatId)) return;

    final result = await ref.read(joinCallUseCaseProvider).execute(chatId);

    await result.match(
      (failure) async {
        state = CallState(
          chatId: chatId,
          chatName: chatName,
          failure: failure,
          layout: state.layout,
          permissionIssue: permissionIssue,
        );
      },
      (token) async {
        final connected = await _service.connect(
          token,
          withMicrophone: microphone.isGranted,
        );
        connected.match(
          (failure) {
            state = CallState(
              chatId: chatId,
              chatName: chatName,
              token: token,
              failure: failure,
              layout: state.layout,
              permissionIssue: permissionIssue,
            );
          },
          (_) {
            _listenToRoom();
            state = state.copyWith(
              stage: CallStage.connected,
              chatId: chatId,
              connectedAt: DateTime.now(),
              token: token,
              isMicrophoneEnabled: microphone.isGranted,
              isCameraEnabled: false,
              canSwitchSpeaker: _service.canSwitchSpeaker,
              clearFailure: true,
              permissionIssue: permissionIssue,
              clearPermissionIssue: permissionIssue == null,
            );
            _syncParticipants();
          },
        );
      },
    );
  }

  /// Leaves the room — the only way out, since api-docs §5.6 has no REST
  /// endpoint for ending or leaving a call.
  Future<void> leave() async {
    await _signals?.cancel();
    _signals = null;
    await _service.disconnect();
    state = CallState(layout: state.layout);
  }

  /// Puts a dropped call back where a fresh one starts, so the screen shows
  /// its join prompt again instead of "call ended" forever.
  void dismissEndedCall() {
    if (state.stage != CallStage.disconnected) return;
    state = CallState(layout: state.layout);
  }

  Future<void> toggleMicrophone() async {
    if (!state.isLive) return;

    final target = !state.isMicrophoneEnabled;
    if (target && !await _ensurePermission(MediaDeviceKind.microphone)) return;

    final result = await _service.setMicrophoneEnabled(target);
    result.match(
      (failure) => state = state.copyWith(failure: failure),
      (_) => state = state.copyWith(
        isMicrophoneEnabled: target,
        clearFailure: true,
      ),
    );
    _syncParticipants();
  }

  Future<void> toggleCamera() async {
    if (!state.isLive) return;

    final target = !state.isCameraEnabled;
    if (target && !await _ensurePermission(MediaDeviceKind.camera)) return;

    final result = await _service.setCameraEnabled(target);
    result.match(
      (failure) => state = state.copyWith(failure: failure),
      (_) =>
          state = state.copyWith(isCameraEnabled: target, clearFailure: true),
    );
    _syncParticipants();
  }

  Future<void> toggleSpeakerphone() async {
    if (!state.isLive || !state.canSwitchSpeaker) return;

    final target = !state.isSpeakerphoneEnabled;
    final result = await _service.setSpeakerphoneEnabled(target);
    result.match(
      (failure) => state = state.copyWith(failure: failure),
      (_) => state = state.copyWith(
        isSpeakerphoneEnabled: target,
        clearFailure: true,
      ),
    );
  }

  void toggleLayout() => state = state.copyWith(layout: state.layout.next);

  /// Pins somebody to the big tile, or unpins them when tapped again.
  void pinParticipant(String? identity) {
    if (identity == null || state.pinnedIdentity == identity) {
      state = state.copyWith(clearPinned: true);
      return;
    }
    state = state.copyWith(
      pinnedIdentity: identity,
      layout: CallLayoutMode.speaker,
    );
  }

  /// Server-side mute of somebody else — gated on `call:mute_member`
  /// (api-docs §5.6) by the caller, which is the only place that knows the
  /// chat membership.
  Future<Failure?> muteParticipant(int userId, {bool muted = true}) async {
    final chatId = state.chatId;
    if (chatId == null) {
      const failure = InputFailure(message: 'Not connected to a call');
      state = state.copyWith(failure: failure);
      return failure;
    }

    final result = await ref
        .read(muteCallParticipantUseCaseProvider)
        .execute(chatId, userId, muted: muted);

    return result.match((failure) {
      state = state.copyWith(failure: failure);
      return failure;
    }, (_) => null);
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);

  void dismissPermissionIssue() =>
      state = state.copyWith(clearPermissionIssue: true);

  /// Sends the user to the settings app for a permission the platform will no
  /// longer prompt for.
  Future<bool> openPermissionSettings() => _permissions.openSettings();

  /// Asks for [device], recording a refusal on the state so the UI can explain
  /// it. Returns whether the toggle that asked may go ahead.
  Future<bool> _ensurePermission(MediaDeviceKind device) async {
    final status = await _permissions.request(device);
    if (status.isGranted) {
      final issue = state.permissionIssue;
      if (issue != null && issue.device == device) {
        state = state.copyWith(clearPermissionIssue: true);
      }
      return true;
    }

    state = state.copyWith(
      permissionIssue: CallPermissionIssue(
        device: device,
        isPermanent: status.needsSettings,
      ),
    );
    return false;
  }

  void _listenToRoom() {
    _signals?.cancel();
    _signals = _service.signals.listen(_onSignal);
  }

  void _onSignal(CallRoomSignal signal) {
    switch (signal) {
      case CallRoomSignal.participants:
        _syncParticipants();
      case CallRoomSignal.reconnecting:
        if (state.isLive) state = state.copyWith(stage: CallStage.reconnecting);
      case CallRoomSignal.reconnected:
        if (state.isLive) state = state.copyWith(stage: CallStage.connected);
        _syncParticipants();
      case CallRoomSignal.disconnected:
        if (!state.isLive) return;
        state = state.copyWith(
          stage: CallStage.disconnected,
          participants: const [],
          isCameraEnabled: false,
        );
    }
  }

  void _syncParticipants() {
    if (state.stage == CallStage.idle) return;

    final room = _service.room;
    if (room == null) {
      state = state.copyWith(participants: const []);
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

    participants.sort((a, b) {
      if (a.isLocal != b.isLocal) return a.isLocal ? -1 : 1;
      return a.identity.compareTo(b.identity);
    });

    state = state.copyWith(
      participants: participants,
      isMicrophoneEnabled:
          local?.isMicrophoneEnabled() ?? state.isMicrophoneEnabled,
      isCameraEnabled: local?.isCameraEnabled() ?? state.isCameraEnabled,
    );
  }

  CallParticipant _map(lk.Participant participant, {required bool isLocal}) {
    lk.VideoTrack? video;
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is lk.VideoTrack && !publication.muted) {
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
      audioLevel: participant.audioLevel,
      isMicrophoneEnabled: participant.isMicrophoneEnabled(),
      isCameraEnabled: participant.isCameraEnabled(),
      quality: _quality(participant.connectionQuality),
      videoTrack: video,
    );
  }

  static CallConnectionQuality _quality(lk.ConnectionQuality quality) =>
      switch (quality) {
        lk.ConnectionQuality.excellent => CallConnectionQuality.excellent,
        lk.ConnectionQuality.good => CallConnectionQuality.good,
        lk.ConnectionQuality.poor => CallConnectionQuality.poor,
        lk.ConnectionQuality.lost => CallConnectionQuality.lost,
        lk.ConnectionQuality.unknown => CallConnectionQuality.unknown,
      };
}

/// Kept alive for the life of the app on purpose: this *is* the call, and a
/// call that ended because the user opened another screen would be a bug.
final callProvider = NotifierProvider<CallController, CallState>(
  CallController.new,
);
