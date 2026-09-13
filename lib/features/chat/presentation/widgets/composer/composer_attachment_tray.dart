import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/providers/chat_attachment_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What is staged for the next message, and how far its upload has got.
///
/// A slot is only spendable once the gateway confirms it, which arrives as
/// the `attachment_success` event rather than in the upload's own response
/// (api-docs §5.5) — hence the separate "processing" state between uploaded
/// and ready.
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

    void clear() => ref.read(chatAttachmentProvider(chatId).notifier).clear();

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
            IconButton(
              tooltip: l10n.clear,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: clear,
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
                tooltip: l10n.clear,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: clear,
              ),
            ],
          ),
          if (state.isUploading)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x2),
              child: LinearProgressIndicator(
                value: state.progress?.fraction,
                minHeight: 2,
              ),
            )
          else if (processing)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.x2),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}
