import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/send_message_use_case.dart';
import 'package:fpdart/fpdart.dart';

/// `POST /chats/{target_chat_id}/messages/forward/` 🔒 10/sec
/// (api-docs §6.4).
///
/// ⚠️ Every parameter is named, deliberately: the destination goes in the URL
/// while the source goes in the body, so a positional call would make
/// "forward A→B" and "forward B→A" indistinguishable at the call site — and
/// getting it backwards posts into the wrong conversation, which cannot be
/// undone by anything short of a delete.
class ForwardMessageUseCase {
  final ChatRepository _repository;

  ForwardMessageUseCase(this._repository);

  Future<Either<Failure, MessageEntity>> execute({
    required String sourceChatId,
    required String sourceMessageId,
    required String targetChatId,
    String? comment,
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
    );
  }

  Future<Either<Failure, MessageEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
