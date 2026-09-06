import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';

class RemoveReactionUseCase {
  final ChatRepository _repository;

  RemoveReactionUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    String messageId,
    String emoji, {
    MessageReactionsEntity? current,
  }) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    if (messageId.trim().isEmpty) return _fail('Message id is required');
    if (emoji.isEmpty || emoji.trim().isEmpty) {
      return _fail('No reaction to remove');
    }
    if (emoji.length > SetReactionUseCase.maxEmojiLength) {
      return _fail('That reaction is not valid');
    }

    if (current != null && !current.isMine(emoji)) {
      return Future.value(const Right(null));
    }

    return _repository.removeReaction(chatId, messageId, emoji);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
