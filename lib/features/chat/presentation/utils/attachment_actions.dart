import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/core/storage/device_file_saver.dart';
import 'package:chatix/core/storage/file_revealer.dart';
import 'package:chatix/core/storage/file_sharer.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_download_provider.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What can be done with an attachment from outside the app: hand it to the
/// platform, keep a copy of it, share it, or find the copy again.
///
/// Shared by the bubble's document row, its context menu and the media
/// viewer, so all of them spell "saved" the same way and all go through the
/// same cache — a file already downloaded once is not fetched again just
/// because it is being saved (api-docs §5.5: the cache is keyed by `s3_key`,
/// not by the link).
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

      AppSnackbar.failure(context, l10n.attachmentSaveFailed);
      return null;
    }

    if (!context.mounted) return null;
    return _keepCopy(context, ref, source: source, attachment: attachment);
  }

  /// [save], for a document in a bubble: the bytes come down through the
  /// document's shared download, so its round button fills while they do.
  static Future<File?> saveDocument(
    BuildContext context,
    WidgetRef ref, {
    required AttachmentEntity attachment,
    required String messageId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final source = await download(
      context,
      ref,
      attachment: attachment,
      messageId: messageId,
      failureMessage: l10n.attachmentSaveFailed,
    );
    if (source == null || !context.mounted) return null;

    return _keepCopy(context, ref, source: source, attachment: attachment);
  }

  /// Brings a document onto this device through its shared download.
  ///
  /// Answers with the cached file, or null — having already said why, in
  /// [failureMessage] or the generic download failure.
  static Future<File?> download(
    BuildContext context,
    WidgetRef ref, {
    required AttachmentEntity attachment,
    required String messageId,
    String? failureMessage,
  }) async {
    final message =
        failureMessage ?? AppLocalizations.of(context).attachmentDownloadFailed;

    final result = await ref
        .read(
          attachmentDownloadProvider(
            attachmentFileKey(attachment, messageId: messageId),
          ).notifier,
        )
        .fetch();

    final file = result.getRight().toNullable();
    if (file != null) return file;

    if (context.mounted && result.getLeft().toNullable() is! CancelledFailure) {
      AppSnackbar.failure(context, message);
    }
    return null;
  }

  /// Opens the system share sheet on a document.
  static Future<void> share(
    BuildContext context,
    WidgetRef ref, {
    required AttachmentEntity attachment,
    required String messageId,
  }) async {
    final l10n = AppLocalizations.of(context);

    // Read before the download: the sheet is anchored where the menu was
    // opened from, and that may be gone once the bytes are here.
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    final source = await download(
      context,
      ref,
      attachment: attachment,
      messageId: messageId,
      failureMessage: l10n.attachmentShareFailed,
    );
    if (source == null || !context.mounted) return;

    try {
      await ref
          .read(fileSharerProvider)
          .share(
            source,
            name: attachment.originalFilename,
            mimeType: attachment.mimeType,
            origin: origin,
          );
    } on Object {
      if (context.mounted) {
        AppSnackbar.failure(context, l10n.attachmentShareFailed);
      }
    }
  }

  /// Opens the file manager on the copy of a document saved this session,
  /// saving one first if there is none yet.
  static Future<void> showInFolder(
    BuildContext context,
    WidgetRef ref, {
    required AttachmentEntity attachment,
    required String messageId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final revealer = ref.read(fileRevealerProvider);

    final saved =
        ref
            .read(savedAttachmentPathsProvider.notifier)
            .find(attachment.s3Key) ??
        await saveDocument(
          context,
          ref,
          attachment: attachment,
          messageId: messageId,
        );
    if (saved == null || !context.mounted) return;

    final shown = await revealer.reveal(saved);
    if (!shown && context.mounted) {
      AppSnackbar.failure(context, l10n.attachmentRevealFailed);
    }
  }

  /// Opens the attachment with whatever the platform has for it.
  ///
  /// On a desktop a copy already on this device — [local] — is opened in
  /// place, in the app that owns its type. Everywhere else, and for a file
  /// not downloaded yet, it goes through a freshly minted presigned link:
  /// handing a local path to another app needs a content provider on
  /// Android and an entitlement on iOS, while a link opens everywhere. The
  /// link lives 300 seconds, which is plenty for a viewer to start reading.
  static Future<void> open(
    BuildContext context,
    WidgetRef ref, {
    required AttachmentEntity attachment,
    required String messageId,
    File? local,
  }) async {
    final l10n = AppLocalizations.of(context);

    if (local != null && _opensLocalFiles && local.existsSync()) {
      final opened = await launchUrl(Uri.file(local.path));
      if (opened || !context.mounted) return;
    }

    final result = await ref
        .read(getAttachmentDownloadUrlUseCaseProvider)
        .execute(attachment.chatId, messageId, attachment.id);

    if (!context.mounted) return;

    await result.match(
      (failure) async =>
          AppSnackbar.failure(context, l10n.attachmentOpenFailed),
      (download) async {
        final uri = Uri.tryParse(download.url);
        final opened =
            uri != null &&
            await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (opened || !context.mounted) return;
        AppSnackbar.failure(context, l10n.attachmentOpenFailed);
      },
    );
  }

  static bool get _opensLocalFiles =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static Future<File?> _keepCopy(
    BuildContext context,
    WidgetRef ref, {
    required File source,
    required AttachmentEntity attachment,
  }) async {
    final l10n = AppLocalizations.of(context);
    // Both read up front: the row that asked may be gone by the time the
    // copy is written, and its `ref` with it.
    final saver = ref.read(deviceFileSaverProvider);
    final paths = ref.read(savedAttachmentPathsProvider.notifier);

    try {
      final saved = await saver.save(
        source: source,
        filename: attachment.originalFilename,
      );
      paths.remember(attachment.s3Key, saved.path);

      if (context.mounted) {
        AppSnackbar.quiet(context, l10n.attachmentSavedTo(saved.path));
      }
      return saved;
    } on FileSystemException {
      if (context.mounted) {
        AppSnackbar.failure(context, l10n.attachmentSaveFailed);
      }
      return null;
    }
  }
}
