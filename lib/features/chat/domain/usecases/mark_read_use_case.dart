import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `POST /chats/{chat_id}/messages/read/` 🔒 → 204 (api-docs §6.4).
///
/// ⚠️ [messageSeq] is a message **`seq`** (the per-chat counter), not a
/// message id — the two are never interchangeable, and a UUID passed here
/// would not even type-check, which is the point of taking an `int`.
class MarkReadUseCase {
  final ChatRepository _repository;

  MarkReadUseCase(this._repository);

  Future<Either<Failure, void>> execute(String chatId, int messageSeq) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (messageSeq < 1) {
      return _fail('A valid message sequence number is required');
    }
    return _repository.markRead(chatId, messageSeq);
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
