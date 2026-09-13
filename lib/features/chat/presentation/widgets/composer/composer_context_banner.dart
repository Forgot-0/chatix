import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What the next message is attached to, when it is attached to anything.
///
/// One strip above the box for both a reply and an edit: they answer the
/// same question — "what am I typing into?" — and two differently shaped
/// banners for that would make the composer look like it has two moods.
///
/// It animates in and out because the box below it does not move otherwise:
/// the strip appearing instantly shoves the whole conversation up a notch.
class ComposerContextBanner extends StatelessWidget {
  const ComposerContextBanner({
    super.key,
    required this.replyTo,
    required this.editing,
    required this.onCancel,
  });

  /// The message the next one answers, or null.
  final MessageEntity? replyTo;

  /// The message being rewritten, or null. Wins over [replyTo]: an edit
  /// takes the whole box, so a reply underneath it is not what is happening.
  final MessageEntity? editing;

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final target = editing ?? replyTo;

    return AnimatedSize(
      duration: AppMotion.base,
      curve: AppMotion.curve,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: AppMotion.base,
        switchInCurve: AppMotion.curve,
        switchOutCurve: AppMotion.reverseCurve,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(
            axisAlignment: -1,
            sizeFactor: animation,
            child: child,
          ),
        ),
        child: target == null
            ? const SizedBox(width: double.infinity, height: 0)
            : _Banner(
                key: ValueKey<String>(
                  '${editing == null ? 'reply' : 'edit'}:${target.id}',
                ),
                message: target,
                isEditing: editing != null,
                onCancel: onCancel,
              ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.message,
    required this.isEditing,
    required this.onCancel,
  });

  final MessageEntity message;
  final bool isEditing;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final title = isEditing
        ? l10n.editingMessage
        : l10n.composerReplyingTo(
            chatDisplayName(message.profile, message.authorId),
          );

    final preview = message.content?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x3,
        AppSpacing.x2,
        AppSpacing.x2,
        0,
      ),
      child: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_outlined : Icons.reply_rounded,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: AppSpacing.x2),
          // The rule is what ties the strip to the quote inside a bubble, so
          // the two read as the same idea in two places.
          Container(
            width: 2,
            height: 30,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(AppRadii.full),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  preview == null || preview.isEmpty
                      ? l10n.attachmentFallbackLabel
                      : preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.cancel,
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
