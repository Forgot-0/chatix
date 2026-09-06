import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

class GetMessagesContextUseCase {
  static const int maxLimit = 100;

  final ChatRepository _repository;

  GetMessagesContextUseCase(this._repository);

  Future<Either<Failure, MessagesPage>> execute(
    String chatId,
    int targetSeq, {
    int limit = 40,
  }) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (targetSeq < 1) {
      return _fail('A valid message is required to jump to');
    }
    if (limit < 1 || limit > maxLimit) {
      return _fail('Limit must be between 1 and $maxLimit');
    }
    return _repository.getMessagesContext(chatId, targetSeq, limit: limit);
  }

  Future<Either<Failure, MessagesPage>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
