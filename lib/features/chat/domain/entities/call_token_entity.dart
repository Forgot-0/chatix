import 'package:equatable/equatable.dart';

/// `JoinTokenDTO` (api-docs §6.6) — the result of `POST /chats/{id}/calls/
/// join/`. Requires the `call:join` permission.
///
/// [token] is a LiveKit access token and [livekitUrl] a `wss://` LiveKit
/// server address, meant for `livekit_client`'s `Room.connect(livekitUrl,
/// token)`. Neither is our Bearer token and neither belongs in an
/// `Authorization` header. Treat both as short-lived secrets: [token] lives
/// `ROOM_TOKEN_TTL = 3600` seconds (§6.6) and is not persisted anywhere in
/// this feature.
///
/// ### Why there is no `LiveKitParticipantsEntity`
///
/// api-docs §6.6 documents a `LiveKitParticipantsDTO`
/// (`identity`, `name`, `state`, `joined_at`), but this client deliberately
/// does **not** model it. The roster the call screen renders comes from the
/// SDK — `CallRoomServiceImpl` listens to `Room` events and maps
/// `livekit_client`'s participants into `CallParticipant`
/// (`call_provider.dart`), which already carries identity, name, speaking
/// state, mute state and the live `VideoTrack`.
///
/// A REST copy would be strictly worse: it is a point-in-time snapshot of
/// data that changes several times a second, it cannot carry tracks, and
/// having two sources for "who is in this call" guarantees they will disagree
/// on screen. It would only be worth adding for something the SDK cannot
/// answer — e.g. listing participants *before* joining the room — and no
/// screen asks for that today.
class CallTokenEntity extends Equatable {
  /// LiveKit access token. ⚠️ TTL `ROOM_TOKEN_TTL = 3600` s (§6.6) — spent on
  /// the initial `Room.connect`; a *reconnect* needs a fresh join call.
  final String token;

  /// LiveKit room identifier — the same slug for every participant of the
  /// chat's active call.
  final String slug;

  final String livekitUrl;

  const CallTokenEntity({
    required this.token,
    required this.slug,
    required this.livekitUrl,
  });

  @override
  List<Object?> get props => [token, slug, livekitUrl];
}
