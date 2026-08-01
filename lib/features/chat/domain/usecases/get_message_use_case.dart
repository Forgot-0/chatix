import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `GET /chats/{chat_id}/messages/{message_id}/` 🔒 (api-docs §6.4).
///
/// Single-message read. Also the documented way to resolve the WebSocket
/// `new_message` / `message_edited` events, which carry only ids and no
/// content (api-docs §7.4) — that consumer arrives with the realtime layer.
class GetMessageUseCase {
  final ChatRepository _repository;

  GetMessageUseCase(this._repository);

  Future<Either<Failure, MessageEntity>> execute(
    String chatId,
    String messageId,
  ) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (messageId.trim().isEmpty) {
      return _fail('Message id is required');
    }
    return _repository.getMessage(chatId, messageId);
  }

  Future<Either<Failure, MessageEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
