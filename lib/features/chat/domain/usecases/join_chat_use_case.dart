import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `POST /chats/{chat_id}/join/` 🔒 10/5min → 204 (api-docs §6.2).
///
/// Self-service join, only possible for chats with `is_public == true`;
/// private chats require an existing member to `addMember` you instead.
/// `409 ALREADY_CHAT_MEMBER` when you're already in.
class JoinChatUseCase {
  final ChatRepository _repository;

  JoinChatUseCase(this._repository);

  Future<Either<Failure, void>> execute(String chatId) {
    if (chatId.trim().isEmpty) {
      return Future.value(
        const Left(InputFailure(message: 'Chat id is required')),
      );
    }
    return _repository.joinChat(chatId);
  }
}
