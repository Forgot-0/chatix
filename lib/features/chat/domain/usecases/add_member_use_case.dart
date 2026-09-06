import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

class AddMemberUseCase {
  static const int maxRoleNameLength = 32;

  final ChatRepository _repository;

  AddMemberUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    int userId, {
    ChatRole role = ChatRole.member,
  }) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (userId <= 0) {
      return _fail('A valid user must be selected');
    }
    return _repository.addMember(chatId, userId, roleId: role.id);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}

String? addMemberFailureMessage(Failure failure) {
  if (failure is! ApiFailure) return null;
  final detail = failure.detail;

  switch (failure.code) {
    case 'TOO_LONG_CHAT_ROLE_NAME':
      final maxLen = detail is Map ? detail['max_len'] : null;
      final limit = maxLen is int ? maxLen : AddMemberUseCase.maxRoleNameLength;
      return 'That role name is too long — $limit characters at most';

    case 'ALREADY_CHAT_MEMBER':
      return 'They are already in this chat';

    case 'MEMBER_LIMIT_EXCEEDED':
      return 'This chat is full — no more members can be added';

    default:
      return null;
  }
}
