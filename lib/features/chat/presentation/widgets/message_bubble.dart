import 'package:flutter/material.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

/// One message row (api-docs §6.4).
///
/// Renders the nested [MessageEntity.replyTo] / [MessageEntity.forwardedFrom]
/// previews and the attachment list. Both nested objects are the same
/// `MessageDTO` shape one level deep and are **not** recursed into — the
/// backend already sends them with their own `reply_to` as `null`.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onReply,
    this.onForward,
    this.onEdit,
    this.onDelete,
    this.onOpenAttachment,
  });

  final MessageEntity message;

  /// Drives alignment/colour. Compared against the caller's own `user_id`
  /// rather than stored on the entity: a `MessageDTO` says nothing about who
  /// is looking at it.
  final bool isMine;

  final VoidCallback? onReply;
  final VoidCallback? onForward;

  /// Null hides the action — the screen decides visibility from the §9.1
  /// permission matrix.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  final void Function(AttachmentEntity attachment)? onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // System messages have no author (`author_id: null`) and belong to
    // neither side — centred, no bubble.
    if (message.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: Center(
          child: Text(
            message.content ?? '',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
          ),
        ),
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showActions(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.all(10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: isMine
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.forwardedFrom != null ||
                  message.forwardedFromMessageId != null)
                _ForwardHeader(message: message),
              if (message.replyTo != null || message.replyToId != null)
                _ReplyPreview(message: message),
              if (message.attachments.isNotEmpty)
                _AttachmentList(
                  attachments: message.attachments,
                  onOpen: onOpenAttachment,
                ),
              if (message.content != null && message.content!.isNotEmpty)
                Text(message.content!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                  if (message.isEdited) ...[
                    const SizedBox(width: 4),
                    Text(
                      'edited',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (onReply != null)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onReply!();
                },
              ),
            if (onForward != null)
              ListTile(
                leading: const Icon(Icons.forward),
                title: const Text('Forward'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onForward!();
                },
              ),
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onEdit!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

/// Header of a forwarded message.
///
/// ⚠️ The flat `forwarded_from_*` ids outlive the nested object: when the
/// source chat is no longer readable by this user the ids are still sent but
/// [MessageEntity.forwardedFrom] comes back `null` (api-docs §6.4). Hence the
/// fallback text instead of assuming the nested object exists.
class _ForwardHeader extends StatelessWidget {
  const _ForwardHeader({required this.message});

  final MessageEntity message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origin = message.forwardedFrom;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forward, size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: 4),
          Text(
            origin == null
                ? 'Forwarded message'
                : 'Forwarded from ${origin.authorId ?? 'unknown'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quoted original of a reply. Same nullability caveat as [_ForwardHeader]:
/// `reply_to_id` may be present while `reply_to` is not.
class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message});

  final MessageEntity message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final original = message.replyTo;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      child: Text(
        original?.content ?? 'Original message unavailable',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

class _AttachmentList extends StatelessWidget {
  const _AttachmentList({required this.attachments, this.onOpen});

  final List<AttachmentEntity> attachments;
  final void Function(AttachmentEntity attachment)? onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final attachment in attachments)
          _AttachmentRow(attachment: attachment, onOpen: onOpen),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment, this.onOpen});

  final AttachmentEntity attachment;
  final void Function(AttachmentEntity attachment)? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // `pending` is the normal state right after sending: `confirm` returns 202
    // and the backend validates the bytes asynchronously (api-docs §6.5), so a
    // freshly sent attachment is expected to show a spinner briefly. The flip
    // to `success` arrives via the WS `attachment_success` event (§7.4), which
    // this REST-only build doesn't listen to — a refresh reveals it.
    final (icon, label) = switch (attachment.attachmentStatus) {
      AttachmentStatus.pending => (Icons.hourglass_empty, 'Processing…'),
      AttachmentStatus.error => (Icons.error_outline, 'Upload failed'),
      AttachmentStatus.success => (
        switch (attachment.attachmentType) {
          AttachmentType.image => Icons.image_outlined,
          AttachmentType.video => Icons.videocam_outlined,
          AttachmentType.file => Icons.attach_file,
        },
        ChatAttachmentLimits.formatBytes(attachment.size),
      ),
    };

    return InkWell(
      // Only a finished attachment has bytes worth downloading.
      onTap: attachment.attachmentStatus == AttachmentStatus.success
          ? () => onOpen?.call(attachment)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.originalFilename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: attachment.attachmentStatus ==
                              AttachmentStatus.error
                          ? theme.colorScheme.error
                          : theme.colorScheme.outline,
                    ),
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
