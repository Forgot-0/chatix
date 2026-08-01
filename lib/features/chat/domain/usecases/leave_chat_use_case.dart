import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `POST /chats/{chat_id}/leave/` 🔒 4/5min → 204 (api-docs §6.2).
class LeaveChatUseCase {
  final ChatRepository _repository;

  LeaveChatUseCase(this._repository);

  Future<Either<Failure, void>> execute(String chatId) {
    if (chatId.trim().isEmpty) {
      return Future.value(
        const Left(InputFailure(message: 'Chat id is required')),
      );
    }
    return _repository.leaveChat(chatId);
  }
}
