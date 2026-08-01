import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `GET /chats/{chat_id}/` 🔒 (api-docs §6.2) → `ChatDetaiDTO`.
///
/// ⚠️ The result carries the full member list but **no** `unread_count`,
/// `me` or `last_read` — those only exist on the `ChatDTO` from `GET /chats/`.
/// Find the caller's own membership with [ChatEntity.membershipOf].
class GetChatUseCase {
  final ChatRepository _repository;

  GetChatUseCase(this._repository);

  Future<Either<Failure, ChatEntity>> execute(String chatId) {
    if (chatId.trim().isEmpty) {
      return Future.value(
        const Left(InputFailure(message: 'Chat id is required')),
      );
    }
    return _repository.getChat(chatId);
  }
}
