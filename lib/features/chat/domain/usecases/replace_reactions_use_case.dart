import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';

class ReplaceReactionsUseCase {
  final ChatRepository _repository;

  ReplaceReactionsUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    String messageId,
    List<String> emojis, {
    ChatReactionPolicy? policy,
  }) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    if (messageId.trim().isEmpty) return _fail('Message id is required');

    final unique = <String>[];
    for (final emoji in emojis) {
      if (!unique.contains(emoji)) unique.add(emoji);
    }

    if (unique.length > ReactionLimits.maxPerUserPerMessage) {
      return _fail(
        'You can add at most ${ReactionLimits.maxPerUserPerMessage} '
        'reactions to a message',
      );
    }

    for (final emoji in unique) {
      final validation = SetReactionUseCase.validateEmoji(emoji);
      if (validation != null) return _fail(validation);

      if (policy != null && !policy.isAllowed(emoji)) {
        return _fail(
          policy.enabled
              ? "That reaction isn't allowed in this chat"
              : 'Reactions are turned off in this chat',
        );
      }
    }

    return _repository.replaceReactions(chatId, messageId, unique);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
