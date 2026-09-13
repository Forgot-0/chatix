import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

/// Everything needed to fetch one attachment: which chat and message it
/// hangs off, and the attachment itself (the `s3_key` inside it is what the
/// cache is keyed by, api-docs §5.5).
typedef AttachmentFileKey = ({
  String chatId,
  String messageId,
  AttachmentEntity attachment,
});

/// An attachment as a local file — from the disk cache when it is there,
/// downloaded when it is not.
///
/// Auto-disposed: the bytes live on disk, so a thumbnail scrolled out of the
/// feed costs nothing to fetch again, and holding every future alive for the
/// length of a session would be the only real cost.
final attachmentFileProvider = FutureProvider.autoDispose
    .family<File, AttachmentFileKey>((ref, key) async {
      final result = await ref
          .read(getAttachmentFileUseCaseProvider)
          .execute(
            chatId: key.chatId,
            messageId: key.messageId,
            attachment: key.attachment,
          );

      return result.fold((failure) => throw failure, (file) => file);
    });

/// The key for [attachmentFileProvider], for callers that only hold the
/// attachment and the message it came in.
AttachmentFileKey attachmentFileKey(
  AttachmentEntity attachment, {
  required String messageId,
}) => (
  chatId: attachment.chatId,
  messageId: messageId,
  attachment: attachment,
);
