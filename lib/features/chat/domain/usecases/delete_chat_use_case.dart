import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `DELETE /chats/{chat_id}/` 🔒 4/5min → 204 (api-docs §6.2).
/// Requires `chat:delete` — owner only (§9.1). Irreversible.
class DeleteChatUseCase {
  final ChatRepository _repository;

  DeleteChatUseCase(this._repository);

  Future<Either<Failure, void>> execute(String chatId) {
    if (chatId.trim().isEmpty) {
      return Future.value(
        const Left(InputFailure(message: 'Chat id is required')),
      );
    }
    return _repository.deleteChat(chatId);
  }
}
