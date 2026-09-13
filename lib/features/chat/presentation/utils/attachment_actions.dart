import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/core/storage/device_file_saver.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The two things that can be done with an attachment from outside the app:
/// hand it to the platform, or keep a copy of it.
///
/// Shared by the bubble's document row and the media viewer so both spell
/// "saved" the same way and both go through the same cache — a file already
/// downloaded once is not fetched again just because it is being saved
/// (api-docs §5.5: the cache is keyed by `s3_key`, not by the link).
abstract final class AttachmentActions {
  /// Downloads the attachment, if need be, and copies it next to the
  /// person's other downloads.
  ///
  /// Answers with the saved file, or null when it did not happen — the
  /// reason has already been said on screen by then.
  static Future<File?> save(
    BuildContext context,
    WidgetRef ref, {
    required AttachmentEntity attachment,
    required String messageId,
    void Function(int received, int total)? onProgress,
    TransferCancellation? cancellation,
  }) async {
    final l10n = AppLocalizations.of(context);

    final result = await ref
        .read(getAttachmentFileUseCaseProvider)
        .execute(
          chatId: attachment.chatId,
          messageId: messageId,
          attachment: attachment,
          onProgress: onProgress,
          cancellation: cancellation,
        );

    final source = result.getRight().toNullable();
    if (source == null) {
      final failure = result.getLeft().toNullable();
      // A cancel is an answer, not a problem worth a message.
      if (!context.mounted || failure is CancelledFailure) return null;

      AppSnackbar.quiet(context, l10n.attachmentSaveFailed);
      return null;
    }

    try {
      final saved = await ref
          .read(deviceFileSaverProvider)
          .save(source: source, filename: attachment.originalFilename);

      if (context.mounted) {
        AppSnackbar.quiet(context, l10n.attachmentSavedTo(saved.path));
      }
      return saved;
    } on FileSystemException {
      if (context.mounted) AppSnackbar.quiet(context, l10n.attachmentSaveFailed);
      return null;
    }
  }

  /// Opens the attachment with whatever the platform has for it.
  ///
  /// Goes through a freshly minted presigned link rather than the cached
  /// file: handing a local path to another app needs a content provider on
  /// Android and an entitlement on iOS, while a link opens everywhere. The
  /// link lives 300 seconds, which is plenty for a viewer to start reading.
  static Future<void> open(
    BuildContext context,
    WidgetRef ref, {
    required AttachmentEntity attachment,
    required String messageId,
  }) async {
    final result = await ref
        .read(getAttachmentDownloadUrlUseCaseProvider)
        .execute(attachment.chatId, messageId, attachment.id);

    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);

    await result.match(
      (failure) async => AppSnackbar.quiet(context, l10n.attachmentOpenFailed),
      (download) async {
        final uri = Uri.tryParse(download.url);
        final opened =
            uri != null &&
            await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (opened || !context.mounted) return;
        AppSnackbar.quiet(context, l10n.attachmentOpenFailed);
      },
    );
  }
}
