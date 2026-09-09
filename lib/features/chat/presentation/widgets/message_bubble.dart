import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/widgets/bubble_shape.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_chip.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/features/chat/presentation/widgets/swipe_to_reply.dart';

import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_picker.dart';
import 'package:chatix/features/chat/presentation/widgets/video_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_player.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
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
    this.reactionPolicy,
    this.onToggleReaction,
    this.onShowReactionUsers,
    this.onJumpToOriginal,
    this.isHighlighted = false,
    this.deliveryStatus,
    this.onStartSelection,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionToggled,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.showAuthor = false,
  });

  final MessageEntity message;

  final bool isMine;

  final VoidCallback? onReply;
  final VoidCallback? onForward;

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  final void Function(AttachmentEntity attachment)? onOpenAttachment;

  final MessageReactionsEntity? reactions;

  final ChatReactionPolicy? reactionPolicy;

  final void Function(String emoji)? onToggleReaction;

  final void Function(String emoji)? onShowReactionUsers;

  /// Ticks for your own message, or null where a tick would be a lie — see
  /// `resolveDeliveryStatus`.
  final MessageDeliveryStatus? deliveryStatus;

  final VoidCallback? onStartSelection;

  final bool selectionMode;

  final bool isSelected;
  final VoidCallback? onSelectionToggled;

  final VoidCallback? onJumpToOriginal;

  final bool isHighlighted;

  final bool isFirstInGroup;
  final bool isLastInGroup;

  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chatix = ChatixTheme.of(context);
    final density = chatix.density;

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

    final foreground = isMine
        ? chatix.bubbleOutgoingForeground
        : chatix.bubbleIncomingForeground;
    final muted = foreground.withValues(alpha: 0.66);

    final shape = BubbleShape.of(
      context,
      isOutgoing: isMine,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
      side: isMine
          ? BorderSide.none
          : BorderSide(color: chatix.bubbleIncomingBorder),
    );

    final authorColor = chatix.authorColor(message.authorId);

    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.bubblePaddingX,
        vertical: density.bubblePaddingY,
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      decoration: ShapeDecoration(
        gradient: isMine ? chatix.bubbleOutgoingGradient : null,
        color: isMine ? null : chatix.bubbleIncoming,
        shape: shape,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAuthor && !isMine)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                message.authorLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: authorColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (message.forwardedFrom != null ||
              message.forwardedFromMessageId != null)
            _ForwardHeader(message: message, foreground: muted),
          if (message.replyTo != null || message.replyToId != null)
            _ReplyPreview(
              message: message,
              onTap: onJumpToOriginal,
              accent: isMine ? foreground : authorColor,
              foreground: muted,
            ),
          if (message.attachments.isNotEmpty)
            _AttachmentList(
              messageId: message.id,
              attachments: message.attachments,
              onOpen: onOpenAttachment,
              foreground: foreground,
            ),
          if (message.content != null && message.content!.isNotEmpty)
            Text(
              message.content!,
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
              if (message.isEdited) ...[
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context).messageEdited,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (deliveryStatus != null) ...[
                const SizedBox(width: 4),
                StatusTicks(status: deliveryStatus!, color: muted),
              ],
            ],
          ),
          if (_hasReactions)
            _ReactionChips(
              groups: reactions!.groups,
              onTap: onToggleReaction,
              onLongPress: onShowReactionUsers,
              onSurface: isMine,
            ),
        ],
      ),
    );

    final bubble = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: ChatixTheme.duration,
        curve: ChatixTheme.curve,
        margin: EdgeInsets.fromLTRB(
          12,
          isFirstInGroup ? density.groupGap : density.stackGap,
          12,
          0,
        ),
        decoration: BoxDecoration(
          color: isHighlighted
              ? scheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(chatix.bubbleRadius),
        ),
        child: SwipeToReply(
          enabled: !selectionMode,
          onReply: onReply,
          child: GestureDetector(
            onTap: selectionMode ? onSelectionToggled : null,
            onLongPress: selectionMode ? null : () => _showActions(context),
            child: content,
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

  bool get _hasReactions => reactions != null && reactions!.groups.isNotEmpty;

  void _showActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final policy = reactionPolicy;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (policy != null && onToggleReaction != null) ...[
              ReactionPicker(
                reactions:
                    reactions ?? MessageReactionsEntity.empty(message.id),
                policy: policy,
                onSelected: (emoji) {
                  Navigator.of(sheetContext).pop();
                  onToggleReaction!(emoji);
                },
              ),
              const Divider(height: 1),
            ],
            if (onReply != null)
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(l10n.messageReply),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onReply!();
                },
              ),
            if (onForward != null)
              ListTile(
                leading: const Icon(Icons.forward),
                title: Text(l10n.messageForward),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onForward!();
                },
              ),
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.messageEdit),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onEdit!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.messageDelete),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onDelete!();
                },
              ),
            if (onStartSelection != null)
              ListTile(
                leading: const Icon(Icons.checklist),
                title: Text(l10n.messageSelect),
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
  const _ForwardHeader({required this.message, required this.foreground});

  final MessageEntity message;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origin = message.forwardedFrom;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forward, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            origin == null
                ? 'Forwarded message'
                : 'Forwarded from ${origin.authorLabel}',
            style: theme.textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({
    required this.message,
    required this.accent,
    required this.foreground,
    this.onTap,
  });

  final MessageEntity message;
  final Color accent;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final original = message.replyTo;
    final l10n = AppLocalizations.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (original != null)
              Text(
                original.authorLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              original?.content ?? l10n.messageNotFound,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentList extends StatelessWidget {
  const _AttachmentList({
    required this.messageId,
    required this.attachments,
    required this.foreground,
    this.onOpen,
  });

  final String messageId;
  final List<AttachmentEntity> attachments;
  final Color foreground;
  final void Function(AttachmentEntity attachment)? onOpen;

  @override
  Widget build(BuildContext context) {
    bool ready(AttachmentEntity a) =>
        a.attachmentStatus == AttachmentStatus.success;

    final images = [
      for (final a in attachments)
        if (a.attachmentType == AttachmentType.image && ready(a)) a,
    ];
    final playable = [
      for (final a in attachments)
        if (ready(a) &&
            (a.attachmentType == AttachmentType.video ||
                a.attachmentType == AttachmentType.videoNote ||
                a.attachmentType == AttachmentType.voice))
          a,
    ];
    final rest = [
      for (final a in attachments)
        if (!images.contains(a) && !playable.contains(a)) a,
    ];

    final accent = ChatixTheme.of(context).success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          _ImageGrid(messageId: messageId, images: images, onOpen: onOpen),
        for (final attachment in playable)
          switch (attachment.attachmentType) {
            AttachmentType.voice => VoicePlayer(
              attachment: attachment,
              messageId: messageId,
              foreground: foreground,
              accent: accent,
            ),
            AttachmentType.videoNote => VideoPreview(
              attachment: attachment,
              messageId: messageId,
              isCircular: true,
            ),
            _ => GestureDetector(
              onTap: () => onOpen?.call(attachment),
              child: VideoPreview(attachment: attachment, messageId: messageId),
            ),
          },
        for (final attachment in rest)
          _AttachmentRow(
            attachment: attachment,
            onOpen: onOpen,
            foreground: foreground,
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.messageId,
    required this.images,
    this.onOpen,
  });

  final String messageId;
  final List<AttachmentEntity> images;
  final void Function(AttachmentEntity attachment)? onOpen;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      final only = images.first;
      final ratio =
          (only.width != null && only.height != null && only.height! > 0)
          ? (only.width! / only.height!).clamp(0.6, 1.8)
          : 1.4;

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: () => onOpen?.call(only),
          child: AspectRatio(
            aspectRatio: ratio.toDouble(),
            child: AttachmentImage(attachment: only, messageId: messageId),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: images.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemBuilder: (context, index) {
          final attachment = images[index];
          return GestureDetector(
            onTap: () => onOpen?.call(attachment),
            child: AttachmentImage(
              attachment: attachment,
              messageId: messageId,
              borderRadius: BorderRadius.circular(8),
            ),
          );
        },
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.attachment,
    required this.foreground,
    this.onOpen,
  });

  final AttachmentEntity attachment;
  final Color foreground;
  final void Function(AttachmentEntity attachment)? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final l10n = AppLocalizations.of(context);

    final (icon, label) = switch (attachment.attachmentStatus) {
      AttachmentStatus.pending => (
        Icons.hourglass_empty,
        l10n.attachmentProcessing,
      ),
      AttachmentStatus.error => (Icons.error_outline, l10n.attachmentFailed),
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
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.originalFilename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          attachment.attachmentStatus == AttachmentStatus.error
                          ? ChatixTheme.of(context).danger
                          : foreground.withValues(alpha: 0.7),
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

/// The row of reactions under a message.
class _ReactionChips extends StatelessWidget {
  const _ReactionChips({
    required this.groups,
    required this.onSurface,
    this.onTap,
    this.onLongPress,
  });

  final List<ReactionGroupEntity> groups;

  /// True when the row sits on the outgoing gradient.
  final bool onSurface;
  final void Function(String emoji)? onTap;
  final void Function(String emoji)? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: AppSpacing.x1,
        runSpacing: AppSpacing.x1,
        children: [
          for (final summary in groups)
            _BloomIn(
              key: ValueKey(summary.emoji),
              child: ReactionChip(
                emoji: summary.emoji,
                count: summary.count,
                selected: summary.reactedByMe,
                recentUserIds: summary.recentUserIds,
                onSurface: onSurface,
                onTap: onTap == null ? null : () => onTap!(summary.emoji),
                onLongPress: onLongPress == null
                    ? null
                    : () => onLongPress!(summary.emoji),
              ),
            ),
        ],
      ),
    );
  }
}

class _BloomIn extends StatefulWidget {
  const _BloomIn({super.key, required this.child});

  final Widget child;

  @override
  State<_BloomIn> createState() => _BloomInState();
}

class _BloomInState extends State<_BloomIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ChatixTheme.duration,
    );
    _curved = CurvedAnimation(parent: _controller, curve: ChatixTheme.curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.6, end: 1).animate(_curved),
      child: FadeTransition(opacity: _curved, child: widget.child),
    );
  }
}
