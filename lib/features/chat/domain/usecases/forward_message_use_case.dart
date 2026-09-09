import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/send_message_use_case.dart';
import 'package:fpdart/fpdart.dart';

class ForwardMessageUseCase {
  final ChatRepository _repository;

  ForwardMessageUseCase(this._repository);

  Future<Either<Failure, MessageEntity>> execute({
    required String sourceChatId,
    required String sourceMessageId,
    required String targetChatId,
    String? comment,
    String? idempotencyKey,
  }) {
    if (sourceChatId.trim().isEmpty) {
      return _fail('Source chat is required');
    }
    if (sourceMessageId.trim().isEmpty) {
      return _fail('Source message is required');
    }
    if (targetChatId.trim().isEmpty) {
      return _fail('Pick a chat to forward to');
    }

    final trimmedComment = comment?.trim();
    if (trimmedComment != null &&
        trimmedComment.length > SendMessageUseCase.maxContentLength) {
      return _fail(
        'Comment is too long: ${trimmedComment.length} characters, '
        'the limit is ${SendMessageUseCase.maxContentLength}',
      );
    }

    return _repository.forwardMessage(
      sourceChatId: sourceChatId,
      sourceMessageId: sourceMessageId,
      targetChatId: targetChatId,
      comment: (trimmedComment == null || trimmedComment.isEmpty)
          ? null
          : trimmedComment,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Either<Failure, MessageEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
