import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

class GetChatsUseCase {
  static const int maxLimit = 100;

  final ChatRepository _repository;

  GetChatsUseCase(this._repository);

  /// The first page of a list.
  ///
  /// [archived] picks which list: the archive is a separate set with its own
  /// cursor, not a slice of the main one (api-docs §5.2). The first page of
  /// either can come back with up to five rows more than [limit] — the
  /// pinned chats ride in front of it and are not part of the cursor.
  Future<Either<Failure, ChatsPage>> execute({
    int limit = 50,
    bool archived = false,
  }) {
    if (limit < 1 || limit > maxLimit) {
      return _fail('Limit must be between 1 and $maxLimit');
    }
    return _repository.getChats(limit: limit, archived: archived);
  }

  Future<Either<Failure, ChatsPage>> executeNextPage(
    ChatsPage previous, {
    int limit = 50,
    bool archived = false,
  }) {
    if (!previous.canLoadMore) {
      return Future.value(
        const Right(
          ChatsPage(
            chats: [],
            hasNext: false,
            nextDate: null,
            nextChatId: null,
          ),
        ),
      );
    }
    if (limit < 1 || limit > maxLimit) {
      return _fail('Limit must be between 1 and $maxLimit');
    }

    return _repository.getChats(
      limit: limit,
      lastChatId: previous.nextChatId,
      lastActivityAt: previous.nextDate == null
          ? null
          : DateTime.tryParse(previous.nextDate!),
      archived: archived,
    );
  }

  Future<Either<Failure, ChatsPage>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
