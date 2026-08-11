import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `POST /chats/{chat_id}/members/` 🔒 30/5min → 204 (api-docs §6.3).
/// Requires `member:invite` (§9.1).
class AddMemberUseCase {
  /// `TOO_LONG_CHAT_ROLE_NAME.detail.max_len` (api-docs §2.3) — the cap on a
  /// custom role's *name*, not on anything this use case sends today.
  static const int maxRoleNameLength = 32;

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

/// Turns an add-member failure into a message that names the actual problem,
/// for the §6.3 codes whose own wording is unhelpful. `null` for anything
/// else, so callers fall back to `failure.message`.
///
/// * `TOO_LONG_CHAT_ROLE_NAME` (400) — `detail` is `{role_name, max_len: 32}`.
///   ⚠️ Not reachable from this client *today*: [AddMemberUseCase] sends a
///   numeric `role_id` from the fixed §9.1 set and never a free-form role
///   name. It is handled anyway because it is documented on this endpoint, and
///   a 400 surfacing as a raw error code is a worse outcome than one dead
///   branch — the day custom role names are added, the message is already
///   right.
/// * `ALREADY_CHAT_MEMBER` (409) — a routine race (invited twice, or the
///   person joined a public chat meanwhile), not an error worth alarming
///   anyone with.
/// * `MEMBER_LIMIT_EXCEEDED` (400) — the chat is full for its type (§6.2).
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
