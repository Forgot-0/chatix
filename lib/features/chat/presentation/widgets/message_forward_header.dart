import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The line that says this message was written somewhere else.
///
/// Deliberately not a quote. A reply points at something still in this
/// conversation and gets a rule down its side; a forward is the message
/// itself, arriving from outside, so it gets a caption above it instead —
/// same shape as a label, not a block someone can tap into.
///
/// `forwarded_from` carries the original when the server could resolve it;
/// `forwarded_from_author_id` is all that survives when it could not
/// (api-docs §5.4), so the header degrades to naming the author, and then to
/// naming nobody.
class MessageForwardHeader extends StatelessWidget {
  const MessageForwardHeader({
    super.key,
    required this.message,
    required this.foreground,
  });

  final MessageEntity message;

  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final origin = message.forwardedFrom;
    final authorId = message.forwardedFromAuthorId;

    final String label;
    if (origin != null) {
      label = l10n.forwardedFrom(origin.authorLabel);
    } else if (authorId != null) {
      label = l10n.forwardedFrom('#$authorId');
    } else {
      label = l10n.forwardedMessage;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shortcut, size: 13, color: foreground),
          const SizedBox(width: AppSpacing.x1 + 1),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: foreground,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
