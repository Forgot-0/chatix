import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';

/// Owns the LiveKit [Room] for a voice/video call (api-docs §6.6).
///
/// This is the third HTTP-free transport in the feature, alongside REST (§6)
/// and the WebSocket (§7): the SDK opens its **own** signalling socket to
/// `livekit_url` using the `token` from `POST /chats/{id}/calls/join/`. Neither
/// of those is our Bearer credential, so nothing here goes through
/// `ApiClient`/`AuthInterceptor` — see [CallTokenEntity].
///
/// Kept behind an interface for the same reason as the attachment uploader:
/// `Room` binds to platform WebRTC at construction, which no widget or unit
/// test can do, so tests substitute a fake instead.
abstract class CallRoomService {
  /// The live room once [connect] succeeds, `null` after [disconnect].
  Room? get room;

  /// Room-level events (participants joining, tracks published, disconnects).
  /// Emits nothing before the first successful [connect].
  Stream<void> get changes;

  /// Connects to [token]'s room and publishes the local mic.
  ///
  /// The camera is deliberately **not** published: §6.6 describes a call
  /// feature with no notion of "this is a video call", and publishing video
  /// unasked would both surprise the user and burn bandwidth. [setCameraEnabled]
  /// turns it on explicitly.
  Future<Either<Failure, Unit>> connect(CallTokenEntity token);

  Future<void> disconnect();

  /// Mutes/unmutes **our own** microphone, locally.
  ///
  /// ⚠️ Not the same thing as `muteCallParticipant` in `ChatRepository`: that
  /// is a moderation action (`POST .../mute/`, permission `call:mute_member`,
  /// §6.6/§9.1) applied to *somebody else* by the server. This is the local
  /// track and needs no permission.
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
    // Reconnecting without tearing the previous room down leaks the old
    // signalling socket and its audio tracks, and the SDK would then publish
    // a second mic track for the same user.
    await disconnect();

    try {
      final room = Room(
        roomOptions: const RoomOptions(
          // Adaptive stream + simulcast keep a group call usable on mobile
          // data; both are no-ops for an audio-only call.
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      // Subscribe *before* connecting so the participant list that arrives
      // with the join response isn't missed.
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
      // Mic on by default — this is a call; video stays off (see [connect]).
      await room.localParticipant?.setMicrophoneEnabled(true);
      _notify();
      return const Right(unit);
    } on ConnectException catch (e) {
      await disconnect();
      // The REST call already succeeded, so a failure here is the media plane:
      // an expired token (they are short-lived), an unreachable `livekit_url`,
      // or a server that rejected the grant — the same conditions the backend
      // reports as `502 LIVEKIT_ERROR/LIVEKIT_UNAUTHORIZED` (§6.6).
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

    // Dispose in this order: the listener first, so the teardown doesn't
    // re-enter `_notify` for the disconnect it is itself causing.
    await listener?.dispose();
    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {
        // Already gone (network dropped, server closed it) — nothing to undo.
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
      // Almost always a denied OS permission prompt; surfaced rather than
      // swallowed so the UI can explain why the button didn't stick.
      return Left(ServerFailure(message: 'Could not toggle the $device: $e'));
    }
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }
}

/// One [CallRoomService] per chat, disposed when the call screen goes away.
///
/// `family` + `autoDispose` (Riverpod 3 disposes by default) is what guarantees
/// the room is torn down on leaving the screen: `onDispose` runs
/// [CallRoomService.disconnect], so navigating away always ends the call
/// instead of leaving a muted-but-live participant in the room.
final callRoomServiceProvider = Provider.family<CallRoomService, String>((
  ref,
  chatId,
) {
  final service = CallRoomServiceImpl();
  ref.onDispose(service.disconnect);
  return service;
});
