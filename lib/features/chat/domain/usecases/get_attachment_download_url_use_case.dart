import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

class GetAttachmentDownloadUrlUseCase {
  final ChatRepository _repository;

  GetAttachmentDownloadUrlUseCase(this._repository);

  Future<Either<Failure, AttachmentDownloadUrlEntity>> execute(
    String chatId,
    String messageId,
    String attachmentId,
  ) {
    if (chatId.trim().isEmpty) {
      return _fail('Chat id is required');
    }
    if (messageId.trim().isEmpty) {
      return _fail('Message id is required');
    }
    if (attachmentId.trim().isEmpty) {
      return _fail('Attachment id is required');
    }
    return _repository.getAttachmentDownloadUrl(chatId, messageId, attachmentId);
  }

  Future<Either<Failure, AttachmentDownloadUrlEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
