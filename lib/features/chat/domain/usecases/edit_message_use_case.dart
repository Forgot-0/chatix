import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/send_message_use_case.dart';
import 'package:fpdart/fpdart.dart';

/// `PATCH /chats/{chat_id}/messages/{message_id}/` 🔒 (api-docs §6.4).
///
/// ⚠️ `EditMessageRequest.content` is `1..4096` — **not** nullable: an edit
/// cannot clear a message's text (that's what delete is for), so empty input
/// is rejected here rather than sent as `""`.
class EditMessageUseCase {
  final ChatRepository _repository;

  EditMessageUseCase(this._repository);

  Future<Either<Failure, MessageEntity>> execute(
    String chatId,
    String messageId,
    String content,
  ) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (messageId.trim().isEmpty) {
      return _fail('Message id is required');
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return _fail('Message text cannot be empty — delete the message instead');
    }
    if (trimmed.length > SendMessageUseCase.maxContentLength) {
      return _fail(
        'Message is too long: ${trimmed.length} characters, '
        'the limit is ${SendMessageUseCase.maxContentLength}',
      );
    }

    return _repository.editMessage(chatId, messageId, trimmed);
  }

  Future<Either<Failure, MessageEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
