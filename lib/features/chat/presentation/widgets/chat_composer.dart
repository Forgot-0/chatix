import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/providers/chat_attachment_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_record_button.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What is staged for the next message, and how far its upload has got.
///
/// A slot is only spendable once the gateway confirms it, which arrives as
/// the `attachment_success` event rather than in the upload's own response
/// (api-docs §5.5) — hence the separate "processing" state between uploaded
/// and ready.
class ChatAttachmentBar extends ConsumerWidget {
  const ChatAttachmentBar({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatAttachmentProvider(chatId)).value;
    final theme = Theme.of(context);

    if (state == null) return const SizedBox.shrink();

    if (state.failure != null) {
      return Container(
        width: double.infinity,
        color: theme.colorScheme.errorContainer,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(state.failure!.message)),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () =>
                  ref.read(chatAttachmentProvider(chatId).notifier).clear(),
            ),
          ],
        ),
      );
    }

    if (!state.hasSelection) return const SizedBox.shrink();

    final totalBytes = state.selected.fold<int>(
      0,
      (sum, upload) => sum + upload.fileSize,
    );

    ref.watch(confirmedAttachmentTokensProvider);
    final confirmed = ref
        .read(confirmedAttachmentTokensProvider.notifier)
        .areReady(state.uploadTokens);

    final processing = state.uploadTokens.isNotEmpty && !confirmed;

    final l10n = AppLocalizations.of(context);

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
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    l10n.attachmentSelection(
                      state.selected.length,
                      ChatAttachmentLimits.formatBytes(totalBytes),
                    ),
                    ?status,
                  ].join(' — '),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () =>
                    ref.read(chatAttachmentProvider(chatId).notifier).clear(),
              ),
            ],
          ),
          if (state.isUploading)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(value: state.progress?.fraction),
            )
          else if (processing)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

/// The message box, its attach button, and the voice or send control.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.disabledReason,
    required this.hasText,
    required this.isRecording,
    this.isEditing = false,
    this.onAttach,
    this.onSend,
    this.onVoiceRecorded,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isEditing;
  final bool hasText;
  final bool isRecording;
  final String disabledReason;
  final void Function(VoiceRecording recording)? onVoiceRecorded;
  final VoidCallback? onAttach;
  final Future<void> Function()? onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);

    if (!enabled) {
      return SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: chatix.composerSurface,
          child: Text(
            disabledReason,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: chatix.composerSurface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              if (!isEditing && !isRecording)
                IconButton(
                  tooltip: l10n.attach,
                  icon: const Icon(Icons.attach_file),
                  onPressed: onAttach,
                ),
              Expanded(
                child: isRecording
                    ? const VoiceRecordingBar()
                    : TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 4096,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: l10n.messageHint,
                          counterText: '',
                          isDense: true,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              if (!isEditing && onVoiceRecorded != null && !hasText)
                VoiceRecordButton(onRecorded: onVoiceRecorded!)
              else
                IconButton.filled(
                  icon: Icon(isEditing ? Icons.check : Icons.send),
                  onPressed: onSend == null ? null : () => onSend!(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the forward picker hands back: where to send, and the optional comment
/// the API accepts alongside a forward (api-docs §5.4 `ForwardMessageRequest`).
