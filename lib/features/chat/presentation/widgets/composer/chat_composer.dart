import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_limits.dart';
import 'package:chatix/features/chat/domain/entities/slow_mode.dart';
import 'package:chatix/features/chat/presentation/providers/composer_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_context_banner.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_field.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_recording_bar.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_send_button.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The bottom of a conversation: what is being written, what it is attached
/// to, and the one control that sends it.
///
/// Deliberately without a `ref` of its own. Everything it needs arrives as a
/// value and every gesture leaves as a callback, so the screen keeps the
/// decisions — whether this reader may send at all, what a slow-mode 429
/// means for the clock — and this stays the part that can be looked at.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.hasAttachments,
    required this.isRecording,
    required this.slowMode,
    this.replyTo,
    this.editing,
    this.isSending = false,
    this.onCancelContext,
    this.onAttach,
    this.onSend,
    this.onVoiceRecorded,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Characters in the box, mirrored out of [controller] so the counter and
  /// the send button rebuild without the field rebuilding under the cursor.
  final int length;

  /// Something is staged and will ride along with the next message, which
  /// makes an empty box sendable.
  final bool hasAttachments;

  final bool isRecording;

  final SlowMode slowMode;

  final MessageEntity? replyTo;
  final MessageEntity? editing;

  final bool isSending;

  /// Drops the reply or abandons the edit, whichever the banner is showing.
  final VoidCallback? onCancelContext;

  /// Null hides the paperclip — an edit cannot gain attachments, since
  /// `PATCH .../messages/{id}/` only carries `content` (api-docs §5.4).
  final VoidCallback? onAttach;

  final VoidCallback? onSend;

  /// Null where voice messages are not on offer; the send button then never
  /// takes its microphone shape.
  final void Function(VoiceRecording recording)? onVoiceRecorded;

  /// Which of its four shapes this is, most specific first.
  ///
  /// An edit claims the box and its text; a reply only adds a banner; staged
  /// uploads only add a tray. Two can be true at once, and this is the order
  /// in which they are answered for.
  ComposerMode get mode {
    if (editing != null) return ComposerMode.editing;
    if (replyTo != null) return ComposerMode.replying;
    if (hasAttachments) return ComposerMode.attaching;
    return ComposerMode.idle;
  }

  bool get _isEditing => mode == ComposerMode.editing;

  /// Whether there is a message to send at all.
  ///
  /// The character cap is checked here rather than left to the server: 4096
  /// is `MESSAGE_TOO_LONG` (api-docs §5.4), and a refusal that arrives after
  /// the box has been cleared is the worst possible moment for it.
  bool get _canSend {
    if (isSending) return false;
    if (MessageLimits.isOverLimit(length)) return false;

    if (_isEditing) {
      // An edit with nothing in it is a delete, which is a different button.
      return length > 0;
    }
    return length > 0 || hasAttachments;
  }

  ComposerAction get _action {
    if (_isEditing) return ComposerAction.save;
    if (_canSend) return ComposerAction.send;

    // Nothing to send: the microphone, unless voice is not on offer here —
    // then the plane stays, greyed, so the control does not vanish.
    return onVoiceRecorded == null
        ? ComposerAction.send
        : ComposerAction.record;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: chatix.composerSurface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ComposerContextBanner(
              replyTo: replyTo,
              editing: editing,
              onCancel: onCancelContext ?? () {},
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x2,
                AppSpacing.x1,
                AppSpacing.x2,
                AppSpacing.x2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // The paperclip leaves during a recording: there is nothing
                  // to attach to a message that is still being spoken.
                  AnimatedSize(
                    duration: AppMotion.base,
                    curve: AppMotion.curve,
                    child: onAttach == null || isRecording
                        ? const SizedBox(height: 44, width: 0)
                        : IconButton(
                            tooltip: l10n.attach,
                            icon: const Icon(Icons.attach_file_rounded),
                            color: theme.colorScheme.onSurfaceVariant,
                            onPressed: onAttach,
                          ),
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x3,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                      ),
                      child: Center(
                        child: isRecording
                            ? const VoiceRecordingBar()
                            : ComposerField(
                                controller: controller,
                                focusNode: focusNode,
                                enabled: !isSending,
                                length: length,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x1),
                  ComposerSendButton(
                    action: _action,
                    enabled: _canSend,
                    slowMode: slowMode,
                    onSend: onSend,
                    onVoiceRecorded: onVoiceRecorded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
