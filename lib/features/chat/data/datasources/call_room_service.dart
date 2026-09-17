import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';

/// What the room just told us, reduced to the four things the call state
/// actually reacts to.
///
/// LiveKit fires a couple of dozen event types; everything that only changes
/// how a tile should look — a track published, somebody muting, the active
/// speaker moving, a connection-quality update — collapses into
/// [CallRoomSignal.participants], because the controller answers all of them
/// the same way: re-read the room and rebuild the participant list. The other
/// three move the call between stages and cannot be derived from the roster.
enum CallRoomSignal { participants, reconnecting, reconnected, disconnected }

abstract class CallRoomService {
  Room? get room;

  Stream<CallRoomSignal> get signals;

  /// Whether this platform has an earpiece/speaker to switch between at all.
  /// Desktop and web do not, and the speaker control stays off the bar there.
  bool get canSwitchSpeaker;

  /// Joins the LiveKit room the join token points at.
  ///
  /// [withMicrophone] publishes the mic as soon as the room is up; the caller
  /// only passes `true` once the microphone permission has actually been
  /// granted, so that the platform prompt never appears mid-connect.
  Future<Either<Failure, Unit>> connect(
    CallTokenEntity token, {
    required bool withMicrophone,
  });

  /// Leaves the room. The only way out — api-docs §5.6 has no REST endpoint
  /// for ending or leaving a call.
  Future<void> disconnect();

  Future<Either<Failure, Unit>> setMicrophoneEnabled(bool enabled);

  Future<Either<Failure, Unit>> setCameraEnabled(bool enabled);

  Future<Either<Failure, Unit>> setSpeakerphoneEnabled(bool enabled);
}

class CallRoomServiceImpl implements CallRoomService {
  CallRoomServiceImpl();

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  final StreamController<CallRoomSignal> _signals =
      StreamController<CallRoomSignal>.broadcast();

  @override
  Room? get room => _room;

  @override
  Stream<CallRoomSignal> get signals => _signals.stream;

  @override
  bool get canSwitchSpeaker => AudioManager.instance.canSwitchSpeakerphone;

  @override
  Future<Either<Failure, Unit>> connect(
    CallTokenEntity token, {
    required bool withMicrophone,
  }) async {
    await disconnect();

    try {
      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );

      final listener = room.createListener();
      listener
        ..on<ParticipantConnectedEvent>(
          (_) => _emit(CallRoomSignal.participants),
        )
        ..on<ParticipantDisconnectedEvent>(
          (_) => _emit(CallRoomSignal.participants),
        )
        ..on<TrackPublishedEvent>((_) => _emit(CallRoomSignal.participants))
        ..on<TrackUnpublishedEvent>((_) => _emit(CallRoomSignal.participants))
        ..on<TrackSubscribedEvent>((_) => _emit(CallRoomSignal.participants))
        ..on<TrackUnsubscribedEvent>((_) => _emit(CallRoomSignal.participants))
        ..on<TrackMutedEvent>((_) => _emit(CallRoomSignal.participants))
        ..on<TrackUnmutedEvent>((_) => _emit(CallRoomSignal.participants))
        ..on<LocalTrackPublishedEvent>(
          (_) => _emit(CallRoomSignal.participants),
        )
        ..on<LocalTrackUnpublishedEvent>(
          (_) => _emit(CallRoomSignal.participants),
        )
        ..on<ActiveSpeakersChangedEvent>(
          (_) => _emit(CallRoomSignal.participants),
        )
        ..on<SpeakingChangedEvent>((_) => _emit(CallRoomSignal.participants))
        ..on<ParticipantNameUpdatedEvent>(
          (_) => _emit(CallRoomSignal.participants),
        )
        ..on<ParticipantConnectionQualityUpdatedEvent>(
          (_) => _emit(CallRoomSignal.participants),
        )
        ..on<RoomReconnectingEvent>((_) => _emit(CallRoomSignal.reconnecting))
        ..on<RoomReconnectedEvent>((_) => _emit(CallRoomSignal.reconnected))
        ..on<RoomDisconnectedEvent>((_) => _emit(CallRoomSignal.disconnected));

      _room = room;
      _listener = listener;

      await room.connect(token.livekitUrl, token.token);
      if (withMicrophone) {
        await room.localParticipant?.setMicrophoneEnabled(true);
      }
      _emit(CallRoomSignal.participants);
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
      } catch (_) {}
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

  @override
  Future<Either<Failure, Unit>> setSpeakerphoneEnabled(bool enabled) async {
    if (!canSwitchSpeaker) {
      return const Left(
        InputFailure(message: 'This device has no speakerphone to switch to'),
      );
    }
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(enabled);
      _emit(CallRoomSignal.participants);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(message: 'Could not switch the speaker: $e'));
    }
  }

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
      _emit(CallRoomSignal.participants);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(message: 'Could not toggle the $device: $e'));
    }
  }

  void _emit(CallRoomSignal signal) {
    if (!_signals.isClosed) _signals.add(signal);
  }
}

/// One room service for the whole app.
///
/// A call is a single thing the device is doing — LiveKit holds one `Room`,
/// the microphone is one device — so this is deliberately not a family:
/// joining a second chat's call replaces the first, which is exactly what
/// [CallRoomServiceImpl.connect] does by disconnecting before it connects.
final callRoomServiceProvider = Provider<CallRoomService>((ref) {
  final service = CallRoomServiceImpl();
  ref.onDispose(service.disconnect);
  return service;
});
