import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:fpdart/fpdart.dart';

/// `GET /chats/{chat_id}/messages/{message_id}/attachments/{attachment_id}/
/// download-url/` 🔒 (api-docs §6.5).
///
/// The returned link lives 300 s, so call this at the moment of use (tap to
/// open/save) and never persist the result alongside the message — a cached
/// URL will simply 403 later.
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
