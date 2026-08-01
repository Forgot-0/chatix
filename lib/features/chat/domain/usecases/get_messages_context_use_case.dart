import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `GET /chats/{chat_id}/messages/context/` 🔒 (api-docs §6.4).
///
/// Returns the window of messages *surrounding* [targetSeq] — both newer and
/// older — which is what "jump to message" needs: opening a reply's original,
/// or landing on a search hit deep in history. Plain `getMessages` can only
/// walk backwards from the newest message and would need many round-trips to
/// reach the same place.
class GetMessagesContextUseCase {
  /// `limit` cap (api-docs §6.4).
  static const int maxLimit = 100;

  final ChatRepository _repository;

  GetMessagesContextUseCase(this._repository);

  Future<Either<Failure, MessagesPage>> execute(
    String chatId,
    int targetSeq, {
    int limit = 40,
  }) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    // `seq` is 1-based and per chat; 0 or negative can only come from a bug
    // (e.g. an uninitialised field), never from a real message.
    if (targetSeq < 1) {
      return _fail('A valid message is required to jump to');
    }
    if (limit < 1 || limit > maxLimit) {
      return _fail('Limit must be between 1 and $maxLimit');
    }
    return _repository.getMessagesContext(chatId, targetSeq, limit: limit);
  }

  Future<Either<Failure, MessagesPage>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
