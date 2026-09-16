import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

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

  /// Lifts a ban through the same endpoint, with a date in the past.
  ///
  /// `PATCH .../ban/` is the only way back in: `banned_to` in the past reads
  /// as an unban server-side (api-docs §5.3). A whole day back rather than a
  /// second, so a clock that disagrees with the server's still lands behind
  /// it. [execute] refuses a past expiry on purpose — an unban says what it
  /// is here instead of arriving as a ban that quietly does the opposite.
  Future<Either<Failure, void>> lift(String chatId, int userId) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (userId <= 0) {
      return _fail('A valid user must be selected');
    }
    return _repository.banMember(
      chatId,
      userId,
      bannedTo: DateTime.now().toUtc().subtract(const Duration(days: 1)),
    );
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
