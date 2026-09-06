import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

class SendMessageUseCase {
  static const int maxContentLength = 4096;

  final ChatRepository _repository;

  SendMessageUseCase(this._repository);

  Future<Either<Failure, MessageEntity>> execute(
    String chatId, {
    String? content,
    String? replyToId,
    MessageType? messageType,
    List<String>? uploadTokens,
    String? idempotencyKey,
  }) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }

    final trimmed = content?.trim();
    final hasText = trimmed != null && trimmed.isNotEmpty;
    final hasAttachments = uploadTokens != null && uploadTokens.isNotEmpty;

    if (!hasText && !hasAttachments) {
      return _fail('Cannot send an empty message');
    }

    if (trimmed != null && trimmed.length > maxContentLength) {
      return _fail(
        'Message is too long: ${trimmed.length} characters, '
        'the limit is $maxContentLength',
      );
    }

    final resolvedType =
        messageType ?? (replyToId != null ? MessageType.reply : null);

    return _repository.sendMessage(
      chatId,
      content: hasText ? trimmed : null,
      replyToId: replyToId,
      messageType: resolvedType,
      uploadTokens: uploadTokens,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Either<Failure, MessageEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
