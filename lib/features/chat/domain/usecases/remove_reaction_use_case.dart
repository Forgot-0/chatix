import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';

/// `DELETE /chats/{chat_id}/messages/{message_id}/reactions/{emoji}/` 🔒
/// 10/sec → 204 (api-docs §6.7.1).
///
/// Takes **one** emoji off the caller's set, leaving any others in place — a
/// user may hold up to [ReactionLimits.maxPerUserPerMessage] of them (§6.7.2).
/// To drop all of them at once use `ClearReactionsUseCase`.
///
/// Removing a reaction the caller never set is a no-op that still answers
/// `204` (§6.7.2), so this is safe to fire from an optimistic UI that may have
/// raced a `reaction_update` event.
///
/// ⚠️ The emoji must be one the caller actually holds; deleting some other
/// emoji silently does nothing rather than clearing "their" reaction. Read the
/// candidates from `MessageReactionsEntity.myEmojis`.
class RemoveReactionUseCase {
  final ChatRepository _repository;

  RemoveReactionUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    String messageId,
    String emoji, {
    /// The message's current reactions, when the caller has them — lets an
    /// emoji the user doesn't hold be skipped instead of spending one of the
    /// 10/sec slots on a guaranteed no-op.
    MessageReactionsEntity? current,
  }) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    if (messageId.trim().isEmpty) return _fail('Message id is required');
    if (emoji.isEmpty || emoji.trim().isEmpty) {
      return _fail('No reaction to remove');
    }
    if (emoji.length > SetReactionUseCase.maxEmojiLength) {
      // Can't correspond to anything stored, so the request would be a
      // guaranteed 400 — refused here to protect the 10/sec budget.
      return _fail('That reaction is not valid');
    }

    // Nothing to remove: the server would no-op, so don't ask it to.
    if (current != null && !current.isMine(emoji)) {
      return Future.value(const Right(null));
    }

    return _repository.removeReaction(chatId, messageId, emoji);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
