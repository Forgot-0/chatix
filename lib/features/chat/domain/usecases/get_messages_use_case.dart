import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `GET /chats/{chat_id}/messages/` 🔒 (api-docs §6.4) — newest first,
/// cursor-paginated by message `seq`.
///
/// "Load more" here walks *backwards into history*, which is the opposite
/// direction from the chat list's pagination — hence [executeOlder] rather
/// than a generic `nextPage` name.
class GetMessagesUseCase {
  /// `limit` cap (api-docs §6.4).
  static const int maxLimit = 100;

  final ChatRepository _repository;

  GetMessagesUseCase(this._repository);

  /// Newest page — no cursor.
  Future<Either<Failure, MessagesPage>> execute(
    String chatId, {
    int limit = 30,
  }) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (limit < 1 || limit > maxLimit) {
      return _fail('Limit must be between 1 and $maxLimit');
    }
    return _repository.getMessages(chatId, limit: limit);
  }

  /// The page of older messages following [previous].
  Future<Either<Failure, MessagesPage>> executeOlder(
    String chatId,
    MessagesPage previous, {
    int limit = 30,
  }) {
    if (!previous.canLoadMore) {
      return Future.value(
        const Right(
          MessagesPage(messages: [], nextCursor: null, hasNext: false),
        ),
      );
    }
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (limit < 1 || limit > maxLimit) {
      return _fail('Limit must be between 1 and $maxLimit');
    }
    return _repository.getMessages(
      chatId,
      limit: limit,
      cursorMessageSeq: previous.nextCursor,
    );
  }

  Future<Either<Failure, MessagesPage>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
