import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

class ClearReactionsUseCase {
  final ChatRepository _repository;

  ClearReactionsUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    String messageId, {
    MessageReactionsEntity? current,
  }) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    if (messageId.trim().isEmpty) return _fail('Message id is required');

    if (current != null && current.myEmojis.isEmpty) {
      return Future.value(const Right(null));
    }

    return _repository.clearReactions(chatId, messageId);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
