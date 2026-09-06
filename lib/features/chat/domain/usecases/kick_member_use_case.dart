import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

class KickMemberUseCase {
  final ChatRepository _repository;

  KickMemberUseCase(this._repository);

  Future<Either<Failure, void>> execute(String chatId, int userId) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (userId <= 0) {
      return _fail('A valid user must be selected');
    }
    return _repository.kickMember(chatId, userId);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
