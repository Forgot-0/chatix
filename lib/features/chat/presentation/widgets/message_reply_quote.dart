import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The message this one is answering, quoted above it.
///
/// `MessageDTO.reply_to` carries the whole original (api-docs §5.4), so the
/// quote can name its author and show what it was without a second request.
/// When the original is gone — deleted, or outside what the client was
/// given — the rule and the placeholder still stand, because a reply with no
/// visible subject reads as a non-sequitur.
class MessageReplyQuote extends StatelessWidget {
  const MessageReplyQuote({
    super.key,
    required this.original,
    required this.accent,
    required this.foreground,
    this.onTap,
  });

  /// Null when the reply points at a message the client does not have.
  final MessageEntity? original;

  /// The original author's colour: the same one their name is drawn in
  /// elsewhere in the conversation, so the rule identifies them at a glance.
  final Color accent;

  final Color foreground;

  final VoidCallback? onTap;

  static const double _thumbnail = 34;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final message = original;

    final preview = message == null ? null : messagePreviewOf(message, l10n);
    final thumbnail = message == null ? null : _thumbnailOf(message);

    return Semantics(
      button: onTap != null,
      label: message == null
          ? l10n.messageNotFound
          : l10n.replyingTo(message.authorLabel),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.x2),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            // A wash behind the quote as well as the rule: on a busy bubble
            // the rule alone does not separate the quote from the reply.
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (thumbnail != null)
                SizedBox.square(
                  dimension: _thumbnail,
                  child: AttachmentImage(
                    attachment: thumbnail,
                    messageId: message!.id,
                  ),
                ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x2,
                    AppSpacing.x1 + 1,
                    AppSpacing.x2,
                    AppSpacing.x1 + 1,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message != null)
                        Text(
                          message.authorLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (preview?.icon != null) ...[
                            Icon(
                              preview!.icon,
                              size: 12,
                              color: foreground,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              preview?.body ?? l10n.messageNotFound,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: foreground,
                                fontStyle: message == null
                                    ? FontStyle.italic
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The first confirmed picture, which is what makes a quote recognisable
  /// at a glance. A slot still uploading has no url to draw.
  static AttachmentEntity? _thumbnailOf(MessageEntity message) {
    for (final attachment in message.attachments) {
      if (attachment.attachmentType == AttachmentType.image &&
          attachment.attachmentStatus == AttachmentStatus.success) {
        return attachment;
      }
    }
    return null;
  }
}
