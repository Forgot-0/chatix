import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

class SetReactionUseCase {
  static const int maxEmojiLength = ReactionLimits.maxEmojiLength;

  final ChatRepository _repository;

  SetReactionUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    String messageId,
    String emoji, {
    MessageReactionsEntity? current,

    ChatReactionPolicy? policy,
  }) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    if (messageId.trim().isEmpty) return _fail('Message id is required');

    final validation = validateEmoji(emoji);
    if (validation != null) return _fail(validation);

    if (policy != null) {
      if (!policy.enabled) {
        return _fail('Reactions are turned off in this chat');
      }
      if (!policy.isAllowed(emoji)) {
        return _fail("That reaction isn't allowed in this chat");
      }
    }

    if (current != null) {
      if (current.isMine(emoji)) return Future.value(const Right(null));

      if (current.myEmojis.length >= ReactionLimits.maxPerUserPerMessage) {
        return _fail(
          'You can add at most ${ReactionLimits.maxPerUserPerMessage} '
          'reactions to a message',
        );
      }
      final exists = current.groups.any((g) => g.emoji == emoji);
      if (!exists &&
          current.groups.length >= ReactionLimits.maxDistinctPerMessage) {
        return _fail('This message has reached its reaction limit');
      }
    }

    return _repository.setReaction(chatId, messageId, emoji);
  }

  static String? validateEmoji(String emoji) {
    if (emoji.isEmpty || emoji.trim().isEmpty) return 'Pick a reaction';
    if (emoji.length > maxEmojiLength) {
      return 'A reaction can be at most $maxEmojiLength characters long';
    }
    if (emoji.codeUnits.contains(0)) {
      return 'That reaction contains an unsupported character';
    }
    return null;
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}

class ChatReactionPolicy {
  final bool enabled;

  final List<String>? whitelist;

  const ChatReactionPolicy({required this.enabled, this.whitelist});

  static const ChatReactionPolicy unrestricted = ChatReactionPolicy(
    enabled: true,
  );

  bool isAllowed(String emoji) {
    if (!enabled) return false;
    final list = whitelist;
    return list == null || list.contains(emoji);
  }
}

extension ChatReactionPolicyX on ChatEntity {
  ChatReactionPolicy get reactionPolicy => ChatReactionPolicy(
    enabled: reactionsEnabled,
    whitelist: reactionWhitelist,
  );
}
