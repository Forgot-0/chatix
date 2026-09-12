import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Everything about one message that the bubble has no room for.
///
/// Opened by tapping the timestamp, which is where someone looks when the
/// short time is not the answer they wanted: the full date, the per-chat
/// `seq` the deep links and read cursors are counted in, and whether each
/// attachment actually made it through (api-docs §5.5).
class MessageDetailsSheet extends StatelessWidget {
  const MessageDetailsSheet({
    super.key,
    required this.message,
    this.deliveryStatus,
  });

  final MessageEntity message;

  final MessageDeliveryStatus? deliveryStatus;

  static Future<void> show(
    BuildContext context, {
    required MessageEntity message,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => MessageDetailsSheet(
        message: message,
        deliveryStatus: deliveryStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final local = message.createdAt.toLocal();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            0,
            AppSpacing.x4,
            AppSpacing.x4,
          ),
          children: [
            Text(
              l10n.messageDetails,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.x3),
            _DetailRow(
              label: l10n.detailsSentAt,
              value:
                  '${material.formatFullDate(local)}, '
                  '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
            ),
            _DetailRow(label: l10n.detailsAuthor, value: message.authorLabel),
            _DetailRow(
              label: l10n.detailsSequence,
              value: '#${message.seq}',
            ),
            if (message.isEdited)
              _DetailRow(
                label: l10n.detailsEdited,
                value: l10n.detailsEditedYes,
              ),
            if (deliveryStatus != null)
              _DetailRow(
                label: l10n.detailsDelivery,
                value: switch (deliveryStatus!) {
                  MessageDeliveryStatus.sending => l10n.messageSending,
                  MessageDeliveryStatus.sent => l10n.messageSent,
                  MessageDeliveryStatus.read => l10n.messageRead,
                },
                trailing: StatusTicks(status: deliveryStatus!),
              ),
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x3),
              Text(
                l10n.detailsAttachments,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.x1),
              for (final attachment in message.attachments)
                _AttachmentStatusRow(attachment: attachment),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1 + 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.x2),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _AttachmentStatusRow extends StatelessWidget {
  const _AttachmentStatusRow({required this.attachment});

  final AttachmentEntity attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    final (icon, color, label) = switch (attachment.attachmentStatus) {
      AttachmentStatus.pending => (
        Icons.hourglass_bottom_outlined,
        theme.colorScheme.onSurfaceVariant,
        l10n.attachmentProcessing,
      ),
      AttachmentStatus.error => (
        Icons.error_outline,
        chatix.danger,
        l10n.attachmentFailed,
      ),
      AttachmentStatus.success => (
        Icons.check_circle_outline,
        chatix.success,
        ChatAttachmentLimits.formatBytes(attachment.size),
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              attachment.originalFilename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
