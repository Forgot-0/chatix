import 'package:flutter/material.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';

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
    this.reactions,
    this.onToggleReaction,
    this.onShowReactionUsers,
    this.readByPeer = false,
    this.showReadTicks = false,
    this.onStartSelection,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionToggled,
  });

  final MessageEntity message;

  final bool isMine;

  final VoidCallback? onReply;
  final VoidCallback? onForward;

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  final void Function(AttachmentEntity attachment)? onOpenAttachment;

  final MessageReactionsEntity? reactions;

  final void Function(String emoji)? onToggleReaction;

  final void Function(String emoji)? onShowReactionUsers;

  final bool readByPeer;

  final bool showReadTicks;

  final VoidCallback? onStartSelection;

  final bool selectionMode;

  final bool isSelected;
  final VoidCallback? onSelectionToggled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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

    final bubble = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: selectionMode ? onSelectionToggled : null,
        onLongPress: selectionMode ? null : () => _showActions(context),
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
                  if (showReadTicks) ...[
                    const SizedBox(width: 4),
                    _ReadTicks(readByPeer: readByPeer),
                  ],
                ],
              ),
              if (_hasReactions)
                _ReactionChips(
                  groups: reactions!.groups,
                  onTap: onToggleReaction,
                  onLongPress: onShowReactionUsers,
                ),
            ],
          ),
        ),
      ),
    );

    if (!selectionMode) return bubble;

    return GestureDetector(
      onTap: onSelectionToggled,
      child: ColoredBox(
        color: isSelected
            ? scheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onSelectionToggled?.call(),
            ),
            Expanded(child: bubble),
          ],
        ),
      ),
    );
  }

  bool get _hasReactions =>
      reactions != null && reactions!.groups.isNotEmpty;

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
            if (onStartSelection != null)
              ListTile(
                leading: const Icon(Icons.checklist),
                title: const Text('Select'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onStartSelection!();
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
                : 'Forwarded from ${origin.authorLabel}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

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

    final (icon, label) = switch (attachment.attachmentStatus) {
      AttachmentStatus.pending => (Icons.hourglass_empty, 'Processing…'),
      AttachmentStatus.error => (Icons.error_outline, 'Upload failed'),
      AttachmentStatus.success => (
        switch (attachment.attachmentType) {
          AttachmentType.image => Icons.image_outlined,
          AttachmentType.video => Icons.videocam_outlined,
          AttachmentType.file => Icons.attach_file,
          AttachmentType.voice => Icons.mic_outlined,
          AttachmentType.videoNote => Icons.videocam_rounded,
        },
        ChatAttachmentLimits.formatBytes(attachment.size),
      ),
    };

    return InkWell(
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
                      color:
                          attachment.attachmentStatus == AttachmentStatus.error
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

class _ReadTicks extends StatelessWidget {
  const _ReadTicks({required this.readByPeer});

  final bool readByPeer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      readByPeer ? Icons.done_all : Icons.done,
      size: 14,
      color: readByPeer ? scheme.primary : scheme.outline,
      semanticLabel: readByPeer ? 'Read' : 'Sent',
    );
  }
}

class _ReactionChips extends StatelessWidget {
  const _ReactionChips({required this.groups, this.onTap, this.onLongPress});

  final List<ReactionGroupEntity> groups;
  final void Function(String emoji)? onTap;
  final void Function(String emoji)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final summary in groups)
            InkWell(
              onTap: onTap == null ? null : () => onTap!(summary.emoji),
              onLongPress: onLongPress == null
                  ? null
                  : () => onLongPress!(summary.emoji),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: summary.reactedByMe
                      ? scheme.primary.withValues(alpha: 0.16)
                      : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: summary.reactedByMe
                        ? scheme.primary
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(summary.emoji, style: theme.textTheme.bodySmall),
                    const SizedBox(width: 4),
                    Text(
                      '${summary.count}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: summary.reactedByMe
                            ? scheme.primary
                            : scheme.outline,
                        fontWeight: summary.reactedByMe
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
