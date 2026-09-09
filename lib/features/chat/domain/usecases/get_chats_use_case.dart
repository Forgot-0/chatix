import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

class GetChatsUseCase {
  static const int maxLimit = 100;

  final ChatRepository _repository;

  GetChatsUseCase(this._repository);

  Future<Either<Failure, ChatsPage>> execute({int limit = 50}) {
    if (limit < 1 || limit > maxLimit) {
      return _fail('Limit must be between 1 and $maxLimit');
    }
    return _repository.getChats(limit: limit);
  }

  Future<Either<Failure, ChatsPage>> executeNextPage(
    ChatsPage previous, {
    int limit = 50,
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
    );
  }

  Future<Either<Failure, ChatsPage>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
