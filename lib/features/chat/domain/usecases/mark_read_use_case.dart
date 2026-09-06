import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

class MarkReadUseCase {
  final ChatRepository _repository;

  MarkReadUseCase(this._repository);

  Future<Either<Failure, void>> execute(String chatId, int messageSeq) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (messageSeq < 1) {
      return _fail('A valid message sequence number is required');
    }
    return _repository.markRead(chatId, messageSeq);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
