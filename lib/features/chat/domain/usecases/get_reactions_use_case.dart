import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

/// `GET /chats/{chat_id}/messages/{message_id}/reactions/` 🔒
/// (api-docs §6.7.1).
///
/// One endpoint, two jobs — which is why [execute] and [executeUsers] are
/// separate entry points onto the same call:
///
/// * [execute] — no `?emoji=`: just the chip summary for a message. This is
///   what a chat screen needs, and the **only** way to get reactions at all:
///   `MessageDTO` has no `reactions` field (api-docs §6.4), so the summary is
///   never delivered with the message and must be fetched once per message
///   (or per visible page) and then kept live by the `reaction_update` WS
///   event (§6.7.5).
/// * [executeUsers] — with `?emoji=`: additionally a page of *who* reacted,
///   for the long-press sheet.
class GetReactionsUseCase {
  /// `limit` cap of the endpoint (api-docs §6.7.1).
  static const int maxLimit = 100;

  static const int defaultLimit = 50;

  final ChatRepository _repository;

  GetReactionsUseCase(this._repository);

  /// Summary only — the chips under one message.
  Future<Either<Failure, MessageReactionsEntity>> execute(
    String chatId,
    String messageId,
  ) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    if (messageId.trim().isEmpty) return _fail('Message id is required');

    return _repository.getReactions(chatId, messageId);
  }

  /// Summary **plus** a page of the people who reacted with [emoji].
  ///
  /// [cursorUserId] continues from the previous response's
  /// [MessageReactionsEntity.nextUserId]; `null` starts at the first page.
  Future<Either<Failure, MessageReactionsEntity>> executeUsers(
    String chatId,
    String messageId, {
    required String emoji,
    int limit = defaultLimit,
    int? cursorUserId,
  }) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    if (messageId.trim().isEmpty) return _fail('Message id is required');
    if (emoji.isEmpty || emoji.trim().isEmpty) {
      return _fail('A reaction is required to list who reacted');
    }
    if (limit < 1 || limit > maxLimit) {
      return _fail('Limit must be between 1 and $maxLimit');
    }
    // `cursor_user_id` is documented as ≥1; 0 or negative would be rejected.
    if (cursorUserId != null && cursorUserId < 1) {
      return _fail('Invalid pagination cursor');
    }

    return _repository.getReactions(
      chatId,
      messageId,
      emoji: emoji,
      limit: limit,
      cursorUserId: cursorUserId,
    );
  }

  Future<Either<Failure, MessageReactionsEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
