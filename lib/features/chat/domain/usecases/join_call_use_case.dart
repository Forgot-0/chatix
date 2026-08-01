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
/// `livekit_client` SDK's job and is out of scope here (the call screen shows
/// the token as a placeholder instead).
class JoinCallUseCase {
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
