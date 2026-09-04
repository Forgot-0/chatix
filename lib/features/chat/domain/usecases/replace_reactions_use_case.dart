import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';

/// `PUT /chats/{chat_id}/messages/{message_id}/reactions/` 🔒 10/sec → 204
/// (api-docs §6.7.1) — **replaces the caller's whole reaction set** on a
/// message with [emojis] (`messages.sendReaction` semantics, §6.7.2).
///
/// Why this exists next to [SetReactionUseCase]: a picker that lets the user
/// choose several emoji at once produces one intent, and expressing it as N
/// adds plus M removes would burn N+M of the 10/sec budget, publish N+M
/// `reaction_update` events, and leave the message in an intermediate state if
/// one of them failed. This is the atomic form.
///
/// An empty [emojis] clears every reaction — the same effect as
/// `ClearReactionsUseCase`, which is the clearer way to say it.
class ReplaceReactionsUseCase {
  final ChatRepository _repository;

  ReplaceReactionsUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    String messageId,
    List<String> emojis, {
    /// The chat's reaction settings (§6.7.5), when known — refuses a set that
    /// the chat's mode/whitelist would reject, without a round trip.
    ChatReactionPolicy? policy,
  }) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    if (messageId.trim().isEmpty) return _fail('Message id is required');

    // De-duplicated because the backend stores a *set*: sending the same emoji
    // twice would count once server-side but could push a legal selection over
    // the limit check below, refusing a request that would have succeeded.
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

    // ⚠️ An empty list is **not** short-circuited: it is the documented way to
    // clear the set, so skipping the call would silently leave the user's
    // existing reactions in place.
    return _repository.replaceReactions(chatId, messageId, unique);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
