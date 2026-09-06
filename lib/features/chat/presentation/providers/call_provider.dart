import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/data/datasources/call_room_service.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

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

enum CallStage { idle, connecting, connected, disconnected }

class CallState extends Equatable {
  final CallStage stage;

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

class CallController extends AsyncNotifier<CallState> {
  CallController(this._chatId);

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
