import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';

abstract class CallRoomService {
  Room? get room;

  Stream<void> get changes;

  Future<Either<Failure, Unit>> connect(CallTokenEntity token);

  Future<void> disconnect();

  Future<Either<Failure, Unit>> setMicrophoneEnabled(bool enabled);

  Future<Either<Failure, Unit>> setCameraEnabled(bool enabled);
}

class CallRoomServiceImpl implements CallRoomService {
  CallRoomServiceImpl();

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Room? get room => _room;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Either<Failure, Unit>> connect(CallTokenEntity token) async {
    await disconnect();

    try {
      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      final listener = room.createListener();
      listener
        ..on<ParticipantConnectedEvent>((_) => _notify())
        ..on<ParticipantDisconnectedEvent>((_) => _notify())
        ..on<TrackPublishedEvent>((_) => _notify())
        ..on<TrackUnpublishedEvent>((_) => _notify())
        ..on<TrackSubscribedEvent>((_) => _notify())
        ..on<TrackUnsubscribedEvent>((_) => _notify())
        ..on<TrackMutedEvent>((_) => _notify())
        ..on<TrackUnmutedEvent>((_) => _notify())
        ..on<LocalTrackPublishedEvent>((_) => _notify())
        ..on<LocalTrackUnpublishedEvent>((_) => _notify())
        ..on<ActiveSpeakersChangedEvent>((_) => _notify())
        ..on<RoomDisconnectedEvent>((_) => _notify());

      _room = room;
      _listener = listener;

      await room.connect(token.livekitUrl, token.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      _notify();
      return const Right(unit);
    } on ConnectException catch (e) {
      await disconnect();
      return Left(
        ServerFailure(message: 'Could not join the call: ${e.toString()}'),
      );
    } catch (e) {
      await disconnect();
      return Left(ServerFailure(message: 'Could not join the call: $e'));
    }
  }

  @override
  Future<void> disconnect() async {
    final listener = _listener;
    final room = _room;
    _listener = null;
    _room = null;

    await listener?.dispose();
    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {
      }
      await room.dispose();
    }
  }

  @override
  Future<Either<Failure, Unit>> setMicrophoneEnabled(bool enabled) =>
      _withLocalParticipant(
        (p) => p.setMicrophoneEnabled(enabled),
        'microphone',
      );

  @override
  Future<Either<Failure, Unit>> setCameraEnabled(bool enabled) =>
      _withLocalParticipant((p) => p.setCameraEnabled(enabled), 'camera');

  Future<Either<Failure, Unit>> _withLocalParticipant(
    Future<void> Function(LocalParticipant participant) action,
    String device,
  ) async {
    final participant = _room?.localParticipant;
    if (participant == null) {
      return const Left(InputFailure(message: 'Not connected to a call'));
    }
    try {
      await action(participant);
      _notify();
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(message: 'Could not toggle the $device: $e'));
    }
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }
}

final callRoomServiceProvider = Provider.family<CallRoomService, String>((
  ref,
  chatId,
) {
  final service = CallRoomServiceImpl();
  ref.onDispose(service.disconnect);
  return service;
});
