import 'package:equatable/equatable.dart';

/// `JoinTokenDTO` (api-docs §6.6) — the result of `POST /chats/{id}/calls/
/// join/`. Requires the `call:join` permission.
///
/// [token] is a LiveKit access token and [livekitUrl] a `wss://` LiveKit
/// server address, meant for `livekit_client`'s `Room.connect(livekitUrl,
/// token)`. Neither is our Bearer token and neither belongs in an
/// `Authorization` header. Treat both as short-lived secrets: they are not
/// persisted anywhere in this feature, and the placeholder call screen shows
/// them only so the flow can be verified end-to-end before a real SDK
/// integration lands.
class CallTokenEntity extends Equatable {
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
