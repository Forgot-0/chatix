import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

/// `DELETE /chats/{chat_id}/messages/{message_id}/reactions/` 🔒 10/sec → 204
/// (api-docs §6.7.1) — drops **all** of the caller's reactions on a message.
///
/// The collection-level counterpart of `RemoveReactionUseCase`, which takes off
/// one emoji at a time. With up to [ReactionLimits.maxPerUserPerMessage] of
/// them held at once, "clear my reactions" would otherwise be three requests
/// and three `reaction_update` events instead of one.
class ClearReactionsUseCase {
  final ChatRepository _repository;

  ClearReactionsUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    String messageId, {
    /// The message's current reactions, when the caller has them — skips the
    /// call when there is nothing of ours to clear, protecting the 10/sec
    /// budget.
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
