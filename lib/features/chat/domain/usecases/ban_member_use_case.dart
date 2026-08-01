import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `PATCH /chats/{chat_id}/members/{user_id}/ban/` 🔒 → 204
/// (api-docs §6.3). Requires `member:ban` (§9.1).
///
/// Distinct from a kick: a ban keeps the person out (and, unlike a kick,
/// survives a re-join attempt on a public chat). Omit [bannedTo] for a
/// permanent ban.
class BanMemberUseCase {
  final ChatRepository _repository;

  BanMemberUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    int userId, {
    String? reason,
    DateTime? bannedTo,
  }) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (userId <= 0) {
      return _fail('A valid user must be selected');
    }
    if (bannedTo != null && !bannedTo.toUtc().isAfter(DateTime.now().toUtc())) {
      // A past expiry would register a ban that is already over — almost
      // certainly a mis-picked date, and impossible to notice afterwards.
      return _fail('The ban expiry must be in the future');
    }
    final trimmedReason = reason?.trim();
    return _repository.banMember(
      chatId,
      userId,
      reason: (trimmedReason == null || trimmedReason.isEmpty)
          ? null
          : trimmedReason,
      bannedTo: bannedTo,
    );
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
