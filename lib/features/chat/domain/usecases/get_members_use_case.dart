import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `GET /chats/{chat_id}/members/` 🔒 (api-docs §6.3) — cursor-paginated.
class GetMembersUseCase {
  /// ⚠️ 500 here, not the 100 that caps the chat and message lists
  /// (api-docs §6.3).
  static const int maxLimit = 500;

  final ChatRepository _repository;

  GetMembersUseCase(this._repository);

  Future<Either<Failure, MembersPage>> execute(
    String chatId, {
    int limit = 50,
    int? cursorUserId,
    bool includePresence = false,
  }) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (limit < 1 || limit > maxLimit) {
      return _fail('Limit must be between 1 and $maxLimit');
    }
    return _repository.getMembers(
      chatId,
      limit: limit,
      cursorUserId: cursorUserId,
      includePresence: includePresence,
    );
  }

  /// Next page, continuing from [previous]. Presence must be requested again
  /// explicitly — it is per-request, not sticky.
  Future<Either<Failure, MembersPage>> executeNextPage(
    String chatId,
    MembersPage previous, {
    int limit = 50,
    bool includePresence = false,
  }) {
    if (!previous.canLoadMore) {
      return Future.value(
        const Right(MembersPage(members: [], hasNext: false, nextUserId: null)),
      );
    }
    return execute(
      chatId,
      limit: limit,
      cursorUserId: previous.nextUserId,
      includePresence: includePresence,
    );
  }

  Future<Either<Failure, MembersPage>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
