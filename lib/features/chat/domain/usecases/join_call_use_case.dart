import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

class JoinCallUseCase {
  static const int tokenTtlSeconds = 3600;

  static const int maxParticipants = 100;

  final ChatRepository _repository;

  JoinCallUseCase(this._repository);

  Future<Either<Failure, CallTokenEntity>> execute(String chatId) {
    if (chatId.trim().isEmpty) {
      return Future.value(
        const Left(InputFailure(message: 'Chat id is required')),
      );
    }
    return _repository.joinCall(chatId);
  }
}
