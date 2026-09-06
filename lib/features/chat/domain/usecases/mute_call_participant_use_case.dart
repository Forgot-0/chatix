import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

class MuteCallParticipantUseCase {
  final ChatRepository _repository;

  MuteCallParticipantUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    int userId, {
    bool muted = true,
  }) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (userId <= 0) {
      return _fail('A valid participant must be selected');
    }
    return _repository.muteCallParticipant(chatId, userId, muted);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
