import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `PATCH /chats/{chat_id}/members/{user_id}/role/` 🔒 → 204
/// (api-docs §6.3). Requires `role:change` (§9.1).
class ChangeMemberRoleUseCase {
  final ChatRepository _repository;

  ChangeMemberRoleUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    int userId,
    ChatRole role,
  ) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (userId <= 0) {
      return _fail('A valid user must be selected');
    }
    // [ChatRole.direct] (id=4) is assigned automatically to both participants
    // of a 1:1 chat and is meaningless anywhere else, so it is not offered as
    // a manual choice.
    if (role == ChatRole.direct) {
      return _fail(
        'The "direct" role is managed automatically for one-to-one chats',
      );
    }
    return _repository.changeMemberRole(chatId, userId, role.id);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
