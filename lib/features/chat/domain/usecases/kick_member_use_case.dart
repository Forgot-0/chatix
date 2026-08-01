import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `DELETE /chats/{chat_id}/members/{user_id}/` 🔒 → 204 (api-docs §6.3).
/// Requires `member:kick` (§9.1).
///
/// A kick only removes the person now — they may re-join a public chat
/// afterwards. Use `BanMemberUseCase` to keep them out.
class KickMemberUseCase {
  final ChatRepository _repository;

  KickMemberUseCase(this._repository);

  Future<Either<Failure, void>> execute(String chatId, int userId) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (userId <= 0) {
      return _fail('A valid user must be selected');
    }
    return _repository.kickMember(chatId, userId);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
