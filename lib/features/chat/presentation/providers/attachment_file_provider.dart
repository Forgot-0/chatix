import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/media_settings_providers.dart';
import 'package:chatix/core/settings/media_settings.dart';
import 'package:chatix/core/storage/cache/attachment_file_cache.dart';
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
}) => (chatId: attachment.chatId, messageId: messageId, attachment: attachment);

/// Which auto-download bucket an attachment falls in.
///
/// Video notes travel with video: they are the same bytes at the same cost,
/// and nobody thinks of them as a separate budget.
MediaKind mediaKindOf(AttachmentType type) => switch (type) {
  AttachmentType.image => MediaKind.photo,
  AttachmentType.video || AttachmentType.videoNote => MediaKind.video,
  AttachmentType.voice => MediaKind.voice,
  AttachmentType.file => MediaKind.file,
};

/// The attachment as a file, but only if fetching it before the reader asks
/// is something their settings allow on this connection.
///
/// Null means "not fetched, and not going to be" — the caller should offer a
/// tap rather than a spinner. A file that is already cached is always
/// returned: the bytes are paid for, and withholding them would punish the
/// reader for a setting that is about the next download, not the last one.
///
/// Watching the policy rather than reading it is deliberate: walking back
/// onto Wi-Fi should start the fetch, without anything having to notice.
final autoAttachmentFileProvider = FutureProvider.autoDispose
    .family<File?, AttachmentFileKey>((ref, key) {
      final allowed = ref.watch(
        autoDownloadProvider(mediaKindOf(key.attachment.attachmentType)),
      );

      // Allowed: the ordinary fetch, which answers from the cache when it
      // can. Not allowed: the cache alone, and null when it has nothing —
      // which is what turns a spinner into a tap.
      //
      // Nothing touches `ref` after an await here, deliberately: this
      // provider is auto-disposed, and a `Ref` used across an async gap can
      // outlive the provider that owns it.
      return allowed
          ? ref.watch(attachmentFileProvider(key).future)
          : ref.read(attachmentFileCacheProvider).find(key.attachment.s3Key);
    });
