import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `POST /chats/{chat_id}/members/` 🔒 30/5min → 204 (api-docs §6.3).
/// Requires `member:invite` (§9.1).
class AddMemberUseCase {
  final ChatRepository _repository;

  AddMemberUseCase(this._repository);

  /// [role] defaults to [ChatRole.member] — the same default the backend
  /// applies to `AddMemberRequest.role_id` (api-docs §9.1). For a channel the
  /// natural choice is [ChatRole.viewer] ("subscriber") instead, which is why
  /// this is a parameter rather than hardcoded.
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
