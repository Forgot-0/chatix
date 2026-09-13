import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/transfer_progress_ring.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/providers/chat_attachment_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/document_attachment_row.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What is staged for the next message, and how far its upload has got.
///
/// Every staged file has its own thumbnail with its own ring, because an
/// album uploads one file at a time and "70%" of a batch says nothing about
/// which photo is still going. The ring counts bytes; once they are all
/// across it spins without a figure, because the slot is only spendable when
/// the gateway says so — `attachment_success` over the socket, not the
/// upload's own response (api-docs §5.5).
///
/// Animated in and out for the same reason the context banner is: this strip
/// appearing between the conversation and the box should push, not jump.
class ComposerAttachmentTray extends ConsumerWidget {
  const ComposerAttachmentTray({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatAttachmentProvider(chatId)).value;

    return AnimatedSize(
      duration: AppMotion.base,
      curve: AppMotion.curve,
      alignment: Alignment.bottomCenter,
      child: state == null || (state.failure == null && !state.hasSelection)
          ? const SizedBox(width: double.infinity, height: 0)
          : _Tray(chatId: chatId, state: state),
    );
  }
}

class _Tray extends ConsumerWidget {
  const _Tray({required this.chatId, required this.state});

  final String chatId;
  final ChatAttachmentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    final notifier = ref.read(chatAttachmentProvider(chatId).notifier);

    if (state.failure != null) {
      return Container(
        width: double.infinity,
        color: theme.colorScheme.errorContainer,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x3,
          AppSpacing.x2,
          AppSpacing.x1,
          AppSpacing.x2,
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 16,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Text(
                state.failure!.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            if (state.hasSelection)
              TextButton(
                onPressed: notifier.retry,
                child: Text(l10n.retry),
              ),
            IconButton(
              tooltip: l10n.clear,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: notifier.clear,
            ),
          ],
        ),
      );
    }

    final totalBytes = state.selected.fold<int>(
      0,
      (sum, upload) => sum + upload.fileSize,
    );

    ref.watch(confirmedAttachmentTokensProvider);
    final confirmed = ref
        .read(confirmedAttachmentTokensProvider.notifier)
        .areReady(state.uploadTokens);

    final processing = state.uploadTokens.isNotEmpty && !confirmed;

    final String? status;
    if (state.isUploading) {
      status = null;
    } else if (processing) {
      status = l10n.attachmentProcessing;
    } else if (state.isReady) {
      status = l10n.attachmentReady;
    } else {
      status = null;
    }

    return Container(
      color: chatix.composerSurface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x3,
        AppSpacing.x2,
        AppSpacing.x1,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  [
                    l10n.attachmentSelection(
                      state.selected.length,
                      ChatAttachmentLimits.formatBytes(totalBytes),
                    ),
                    ?status,
                  ].join(' — '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: state.isUploading ? l10n.cancel : l10n.clear,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: notifier.cancel,
              ),
            ],
          ),
          SizedBox(
            height: _thumbSize + AppSpacing.x2,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: AppSpacing.x2),
              itemCount: state.selected.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x2),
              itemBuilder: (context, index) => _StagedThumb(
                upload: state.selected[index],
                // Only the file actually moving has a figure to show; the
                // ones behind it are waiting, the ones before it are done.
                progress: _progressOf(index),
                isUploading: state.isUploading,
                isProcessing: processing,
                onRemove: state.isUploading || state.isReady
                    ? null
                    : () => notifier.removeAt(index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _thumbSize = 56;

  double? _progressOf(int index) => state.progress?.fractionOf(index);
}

/// One staged file: what it looks like, and what is happening to it.
class _StagedThumb extends StatelessWidget {
  const _StagedThumb({
    required this.upload,
    required this.progress,
    required this.isUploading,
    required this.isProcessing,
    this.onRemove,
  });

  final AttachmentUploadRequestEntity upload;
  final double? progress;
  final bool isUploading;
  final bool isProcessing;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final done = progress != null && progress! >= 1;

    return SizedBox(
      width: _Tray._thumbSize,
      height: _Tray._thumbSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Thumbnail(upload: upload),
            if (isUploading && !done)
              Center(
                child: TransferProgressRing(
                  state: TransferRingState.running,
                  progress: progress,
                  size: 34,
                  semanticLabel: l10n.attachmentUploading,
                ),
              )
            else if (isProcessing)
              Center(
                child: TransferProgressRing(
                  state: TransferRingState.waiting,
                  size: 34,
                  semanticLabel: l10n.attachmentProcessing,
                ),
              ),
            if (onRemove != null)
              Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkResponse(
                    onTap: onRemove,
                    radius: 14,
                    child: Tooltip(
                      message: l10n.mediaPreviewRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (upload.resolvedType == AttachmentType.file)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: scheme.surface.withValues(alpha: 0.8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      upload.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A staged file's picture: the image itself when there is one, and the
/// kind of file it is when there is not.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.upload});

  final AttachmentUploadRequestEntity upload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = upload.resolvedType;

    if (type == AttachmentType.image) {
      final path = upload.filePath;
      if (path != null) {
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _glyph(scheme, Icons.image_outlined),
        );
      }

      final bytes = upload.bytes;
      if (bytes != null) {
        return Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _glyph(scheme, Icons.image_outlined),
        );
      }
    }

    return switch (type) {
      AttachmentType.video => _glyph(scheme, Icons.movie_creation_outlined),
      AttachmentType.voice => _glyph(scheme, Icons.mic_none_rounded),
      AttachmentType.videoNote => _glyph(scheme, Icons.videocam_rounded),
      _ => _glyph(scheme, DocumentKind.of(upload.filename).icon),
    };
  }

  Widget _glyph(ColorScheme scheme, IconData icon) => ColoredBox(
    color: scheme.surfaceContainerHighest,
    child: Icon(icon, color: scheme.onSurfaceVariant, size: 22),
  );
}
