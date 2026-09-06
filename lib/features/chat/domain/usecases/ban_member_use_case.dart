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

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
