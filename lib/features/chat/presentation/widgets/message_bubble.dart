import 'package:flutter/material.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';

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

  /// Reaction chips for this message (§6.7). `null` and empty render the same
  /// way — an absent chip row — so the caller need not distinguish them.
  ///
  /// Sourced from [MessageEntity.reactions]: since §6.7.3 `MessageDTO` carries
  /// its reactions inline (§6.4), so there is no companion fetch and no
  /// separate summary map to keep in step with the message.
  final MessageReactionsEntity? reactions;

  /// Tap on a chip — adds or removes that one emoji from the viewer's set.
  ///
  /// ⚠️ Not a single choice: a user may hold up to three different emoji on
  /// one message (§6.7.2), so this never implies removing another chip. The
  /// limit and the chat's `reactions_mode` are enforced in the controller.
  final void Function(String emoji)? onToggleReaction;

  /// Long-press on a chip — opens the "who reacted" sheet via
  /// `GET .../reactions/?emoji=`.
  final void Function(String emoji)? onShowReactionUsers;

  /// Whether the peer has read this message; drives the double tick.
  ///
  /// Only ever true in a direct chat — see `ChatDetailState.isReadByPeer` for
  /// why group read state is deliberately not aggregated.
  final bool readByPeer;

  /// Whether to render ticks at all. False for other people's messages (in
  /// Telegram only your own carry them) and for chat types where the receipt
  /// has no unambiguous meaning.
  final bool showReadTicks;

  /// Long-press action that turns on the screen's multi-select mode.
  final VoidCallback? onStartSelection;

  /// While true, a plain tap toggles the checkbox instead of doing anything
  /// else, and long-press actions are suppressed.
  final bool selectionMode;

  final bool isSelected;
  final VoidCallback? onSelectionToggled;

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

    final bubble = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        // In selection mode a tap toggles the checkbox and long-press does
        // nothing: the single-message action sheet has no meaning once several
        // messages are selected.
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
              // Chips sit *inside* the bubble, below the timestamp, so they
              // inherit its max-width constraint and wrap instead of stretching
              // the row.
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

    // Selection mode wraps rather than replaces the bubble, so the row keeps
    // its exact layout and only gains a checkbox and a tinted background.
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
            // Prefer the denormalized author profile on the nested original
            // (api-docs §6.4). `origin == null` means the source is no longer
            // readable by us, so there is no author to name at all.
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
          AttachmentType.voice => Icons.mic_outlined,
          AttachmentType.videoNote => Icons.videocam_rounded,
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

/// Delivery/read ticks for the viewer's own messages.
///
/// Telegram semantics, and only where they are unambiguous: one tick means
/// "sent" (the server accepted it — it has an id and a seq), two mean the peer
/// has read up to this message.
///
/// ⚠️ There is no "delivered to device" state anywhere in the protocol, so the
/// single tick deliberately means *sent*, not delivered. Inventing a third
/// state would be a lie the backend cannot back up.
class _ReadTicks extends StatelessWidget {
  const _ReadTicks({required this.readByPeer});

  final bool readByPeer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      readByPeer ? Icons.done_all : Icons.done,
      size: 14,
      // Read ticks are tinted, unread ones stay muted — the same "something
      // changed" cue Telegram uses, without relying on the icon shape alone.
      color: readByPeer ? scheme.primary : scheme.outline,
      semanticLabel: readByPeer ? 'Read' : 'Sent',
    );
  }
}

/// The row of reaction chips under a message (§6.7.3).
///
/// One chip per emoji with its **absolute** count, ordered by the backend
/// (`count DESC, emoji ASC`, §6.7.3).
///
/// ⚠️ **Several chips can be "mine" at once.** A user may hold up to
/// `ReactionLimits.maxPerUserPerMessage` (3) different emoji on one message
/// (§6.7.2), so the outlined/tinted treatment is per chip, not a single
/// selection — a layout that assumed one highlighted chip would be wrong.
///
/// Tap adds or removes that one emoji; long-press opens the "who reacted"
/// sheet.
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
                      // The count is absolute (§6.7.3/§6.7.6) and a chip with
                      // count 0 is removed upstream, so this never renders "0".
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
