import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

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
