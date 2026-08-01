import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `GET /chats/` 🔒 (api-docs §6.2) — cursor-paginated chat list.
///
/// The cursor is the **pair** (`last_activity_at`, `last_chat_id`), which is
/// why [executeNextPage] takes a whole [ChatsPage] instead of loose values:
/// passing only one half silently reads the wrong window (`last_activity_at`
/// is not unique across chats), and that's an easy mistake to make at a call
/// site juggling two nullable cursor fields.
class GetChatsUseCase {
  /// `limit` cap (api-docs §6.2).
  static const int maxLimit = 100;

  final ChatRepository _repository;

  GetChatsUseCase(this._repository);

  /// First page — no cursor.
  Future<Either<Failure, ChatsPage>> execute({int limit = 50}) {
    if (limit < 1 || limit > maxLimit) {
      return _fail('Limit must be between 1 and $maxLimit');
    }
    return _repository.getChats(limit: limit);
  }

  /// Next page, continuing from [previous].
  ///
  /// Returns an empty, exhausted page when [previous] has no continuation, so
  /// an over-eager scroll listener can't loop forever on a final page.
  Future<Either<Failure, ChatsPage>> executeNextPage(
    ChatsPage previous, {
    int limit = 50,
  }) {
    if (!previous.canLoadMore) {
      return Future.value(
        const Right(
          ChatsPage(chats: [], hasNext: false, nextDate: null, nextChatId: null),
        ),
      );
    }
    if (limit < 1 || limit > maxLimit) {
      return _fail('Limit must be between 1 and $maxLimit');
    }

    return _repository.getChats(
      limit: limit,
      lastChatId: previous.nextChatId,
      // `nextDate` is an opaque ISO string; parsed only here, at the edge, and
      // never stored as a `DateTime` in between (see [ChatsPage.nextDate]).
      lastActivityAt: previous.nextDate == null
          ? null
          : DateTime.tryParse(previous.nextDate!),
    );
  }

  Future<Either<Failure, ChatsPage>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
