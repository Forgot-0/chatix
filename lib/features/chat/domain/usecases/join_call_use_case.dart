import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `POST /chats/{chat_id}/calls/join/` 🔒 10/5min (api-docs §6.6).
///
/// Yields a LiveKit access token + server URL. Requires `call:join`, which
/// every chat role holds by default (§9.1) — so the button is hidden only
/// when an override revokes it.
///
/// This use case stops at the token: connecting it to a room is the
/// `livekit_client` SDK's job, handled by `CallRoomService`.
///
/// ### Server-side limits worth knowing here (§6.6)
///
/// * **`ROOM_TOKEN_TTL = 3600`** — the token is valid for one hour. It is
///   spent immediately on `Room.connect`, so the TTL only matters if a token
///   is held before use; never cache one across app launches. See
///   [JoinCallUseCase.tokenTtlSeconds].
/// * **`ROOM_MAX_PARTICIPANTS = 100`** — hard cap per room, enforced by the
///   backend at join time. Not pre-checked on the client: the count of who is
///   *currently* connected is only known to LiveKit, so a local guess would
///   be wrong more often than the server's answer.
///
/// ### ⚠️ There is no "end call" endpoint
///
/// §6.6 exposes join and mute-participant, and nothing else. Leaving a call
/// is **purely a LiveKit SDK operation** — `Room.disconnect()`, via
/// `CallRoomService.leave()`. There is no REST call to make afterwards and no
/// server state to clean up: the room dissolves on its own once the last
/// participant disconnects. A "hang up" button that only hits the backend
/// would leave the user connected and audible.
class JoinCallUseCase {
  /// `ROOM_TOKEN_TTL` (api-docs §6.6) — lifetime of the returned token.
  static const int tokenTtlSeconds = 3600;

  /// `ROOM_MAX_PARTICIPANTS` (api-docs §6.6) — participants per room. Exposed
  /// for copy ("this call is full") rather than for a pre-flight check; see
  /// the class doc.
  static const int maxParticipants = 100;

  final ChatRepository _repository;

  JoinCallUseCase(this._repository);

  Future<Either<Failure, CallTokenEntity>> execute(String chatId) {
    if (chatId.trim().isEmpty) {
      return Future.value(
        const Left(InputFailure(message: 'Chat id is required')),
      );
    }
    return _repository.joinCall(chatId);
  }
}
