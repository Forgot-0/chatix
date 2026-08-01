import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `DELETE /chats/{chat_id}/messages/{message_id}/` 🔒 → 204
/// (api-docs §6.4). Deleting somebody else's message needs `message:delete`
/// (§9.1).
class DeleteMessageUseCase {
  final ChatRepository _repository;

  DeleteMessageUseCase(this._repository);

  Future<Either<Failure, void>> execute(String chatId, String messageId) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (messageId.trim().isEmpty) {
      return _fail('Message id is required');
    }
    return _repository.deleteMessage(chatId, messageId);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
