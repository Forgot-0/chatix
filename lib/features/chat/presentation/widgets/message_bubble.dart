import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/presentation/utils/message_actions.dart';
import 'package:chatix/features/chat/presentation/utils/message_linkifier.dart';
import 'package:chatix/features/chat/presentation/widgets/bubble_shape.dart';
import 'package:chatix/features/chat/presentation/widgets/message_actions_overlay.dart';
import 'package:chatix/features/chat/presentation/widgets/message_attachments.dart';
import 'package:chatix/features/chat/presentation/widgets/message_forward_header.dart';
import 'package:chatix/features/chat/presentation/widgets/message_reply_quote.dart';
import 'package:chatix/features/chat/presentation/widgets/message_text.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_chip.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/features/chat/presentation/widgets/swipe_to_reply.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One message.
///
/// Everything about *what* the bubble may do arrives decided: [actions] is
/// built from [MessageActions] against the reader's rights, and the callbacks
/// are only non-null where the corresponding right exists. The bubble neither
/// reads roles nor guesses at them.
///
/// A deleted message is not drawn here at all — `message_deleted` drops it
/// from the window, so there is no tombstone state to render.
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.actions = const [],
    this.onReply,
    this.onForward,
    this.onEdit,
    this.onDelete,
    this.onCopy,
    this.onShowDetails,
    this.onOpenAttachment,
    this.onOpenLink,
    this.isKnownMention,
    this.reactions,
    this.quickReactions = const [],
    this.onToggleReaction,
    this.onShowReactionPicker,
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
    this.showMeta = true,
  });

  final MessageEntity message;

  final bool isMine;

  /// What the long-press menu offers, in order. Empty disables the menu.
  final List<MessageAction> actions;

  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;
  final VoidCallback? onShowDetails;

  final void Function(AttachmentEntity attachment)? onOpenAttachment;

  /// Opening a url, an address or a phone number found in the text, or
  /// visiting the person a mention names.
  final void Function(LinkSpan link)? onOpenLink;

  /// Decides which `@handle` in the text is somebody in this conversation.
  final bool Function(String handle)? isKnownMention;

  final MessageReactionsEntity? reactions;

  /// The emoji the quick bar offers, already filtered by what this chat
  /// allows and ordered by what this reader reaches for. The first is what a
  /// double tap sends.
  final List<String> quickReactions;

  final void Function(String emoji)? onToggleReaction;

  /// Opens the full set of emoji this chat allows, for when the handful on
  /// the quick bar is not the one someone wanted.
  final VoidCallback? onShowReactionPicker;

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

  /// Whether this bubble carries the timestamp and the delivery ticks.
  ///
  /// Off for every message in a run but the last, which is what turns a burst
  /// of messages into one block instead of a column of clocks. An edited
  /// message shows them anyway: the "edited" mark lives on that row, and
  /// hiding it would quietly drop the only sign the text changed.
  final bool showMeta;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  /// Measured when the menu opens, so the overlay can redraw the bubble
  /// exactly where the reader pressed it.
  final GlobalKey _bubbleKey = GlobalKey();

  bool _menuOpen = false;

  MessageEntity get _message => widget.message;

  @override
  Widget build(BuildContext context) {
    if (_message.type == MessageType.system) {
      return _SystemMessage(
        message: _message,
        onLongPress: widget.actions.isEmpty ? null : _openMenu,
      );
    }

    final bubble = _buildBubble(context, forOverlay: false);

    if (!widget.selectionMode) return bubble;

    return _SelectionRow(
      isSelected: widget.isSelected,
      onToggle: widget.onSelectionToggled,
      child: bubble,
    );
  }

  /// The bubble and its margins.
  ///
  /// [forOverlay] draws the same thing without the gestures or the selection
  /// chrome: the copy the context menu lifts over the blur has to look
  /// identical and do nothing.
  Widget _buildBubble(BuildContext context, {required bool forOverlay}) {
    final chatix = ChatixTheme.of(context);
    final density = chatix.density;
    final scheme = Theme.of(context).colorScheme;

    final content = _BubbleBody(
      message: _message,
      isMine: widget.isMine,
      showAuthor: widget.showAuthor,
      showMeta: widget.showMeta,
      deliveryStatus: widget.deliveryStatus,
      reactions: widget.reactions,
      isFirstInGroup: widget.isFirstInGroup,
      isLastInGroup: widget.isLastInGroup,
      onJumpToOriginal: forOverlay ? null : widget.onJumpToOriginal,
      onOpenAttachment: forOverlay ? null : widget.onOpenAttachment,
      onOpenLink: forOverlay ? null : widget.onOpenLink,
      isKnownMention: widget.isKnownMention,
      onToggleReaction: forOverlay ? null : widget.onToggleReaction,
      onShowReactionUsers: forOverlay ? null : widget.onShowReactionUsers,
      onShowDetails: forOverlay ? null : widget.onShowDetails,
    );

    // The overlay positions its copy at the measured rect, so the copy is
    // the bubble alone — any alignment or margin around it would be counted
    // twice and squeeze it.
    if (forOverlay) return content;

    final aligned = Align(
      alignment: widget.isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: KeyedSubtree(key: _bubbleKey, child: content),
    );

    return AnimatedContainer(
      duration: ChatixTheme.duration,
      curve: ChatixTheme.curve,
      margin: EdgeInsets.fromLTRB(
        AppSpacing.x3,
        widget.isFirstInGroup ? density.groupGap : density.stackGap,
        AppSpacing.x3,
        0,
      ),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? scheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(chatix.bubbleRadius),
      ),
      child: SwipeToReply(
        enabled: !widget.selectionMode && !_menuOpen,
        onReply: widget.onReply,
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: widget.selectionMode ? widget.onSelectionToggled : null,
          onDoubleTap: widget.selectionMode ? null : _quickReact,
          onLongPress: widget.selectionMode || widget.actions.isEmpty
              ? null
              : _openMenu,
          child: aligned,
        ),
      ),
    );
  }

  /// Double tap sends the reaction this person reaches for most.
  ///
  /// Tapping again with the same emoji takes it back, which is what makes the
  /// gesture safe to use by accident.
  void _quickReact() {
    final emoji = widget.quickReactions.firstOrNull;
    final toggle = widget.onToggleReaction;
    if (emoji == null || toggle == null) return;

    HapticFeedback.selectionClick();
    toggle(emoji);
  }

  Future<void> _openMenu() async {
    final anchor = _anchorRect();
    if (anchor == null || !mounted) return;

    HapticFeedback.mediumImpact();
    setState(() => _menuOpen = true);

    final result = await MessageActionsOverlay.show(
      context,
      anchor: anchor,
      bubble: _buildBubble(context, forOverlay: true),
      actions: widget.actions,
      reactions: widget.onToggleReaction == null
          ? const []
          : widget.quickReactions,
      myReactions: widget.reactions?.myEmojis.toSet() ?? const {},
      isMine: widget.isMine,
    );

    if (!mounted) return;
    setState(() => _menuOpen = false);

    if (result == null) return;

    final emoji = result.emoji;
    if (emoji != null) {
      widget.onToggleReaction?.call(emoji);
      return;
    }

    switch (result.action!) {
      case MessageAction.reply:
        widget.onReply?.call();
      case MessageAction.react:
        widget.onShowReactionPicker?.call();
      case MessageAction.copy:
        widget.onCopy?.call();
      case MessageAction.forward:
        widget.onForward?.call();
      case MessageAction.edit:
        widget.onEdit?.call();
      case MessageAction.select:
        widget.onStartSelection?.call();
      case MessageAction.delete:
        widget.onDelete?.call();
      case MessageAction.details:
        widget.onShowDetails?.call();
    }
  }

  /// Where the bubble sits on screen right now, in global coordinates.
  Rect? _anchorRect() {
    final render = _bubbleKey.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return null;
    return render.localToGlobal(Offset.zero) & render.size;
  }
}

/// The painted bubble: its shape, its ground, and everything inside it.
class _BubbleBody extends StatelessWidget {
  const _BubbleBody({
    required this.message,
    required this.isMine,
    required this.showAuthor,
    required this.showMeta,
    required this.deliveryStatus,
    required this.reactions,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.onJumpToOriginal,
    required this.onOpenAttachment,
    required this.onOpenLink,
    required this.isKnownMention,
    required this.onToggleReaction,
    required this.onShowReactionUsers,
    required this.onShowDetails,
  });

  final MessageEntity message;
  final bool isMine;
  final bool showAuthor;
  final bool showMeta;
  final MessageDeliveryStatus? deliveryStatus;
  final MessageReactionsEntity? reactions;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final VoidCallback? onJumpToOriginal;
  final void Function(AttachmentEntity attachment)? onOpenAttachment;
  final void Function(LinkSpan link)? onOpenLink;
  final bool Function(String handle)? isKnownMention;
  final void Function(String emoji)? onToggleReaction;
  final void Function(String emoji)? onShowReactionUsers;
  final VoidCallback? onShowDetails;

  bool get _hasReactions =>
      reactions != null && reactions!.groups.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final density = chatix.density;

    final foreground = isMine
        ? chatix.bubbleOutgoingForeground
        : chatix.bubbleIncomingForeground;
    final muted = foreground.withValues(alpha: 0.66);
    final authorColor = chatix.authorColor(message.authorId);

    final content = message.content;
    final hasText = content != null && content.isNotEmpty;

    return Container(
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
        shape: BubbleShape.of(
          context,
          isOutgoing: isMine,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
          side: isMine
              ? BorderSide.none
              : BorderSide(color: chatix.bubbleIncomingBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Without this the bubble swells to whatever height it is offered,
        // which is also the rect the context menu measures to lift it.
        mainAxisSize: MainAxisSize.min,
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
          if (message.isForward)
            MessageForwardHeader(message: message, foreground: muted),
          if (message.isReply)
            MessageReplyQuote(
              original: message.replyTo,
              // On the outgoing gradient the author palette has nothing to
              // sit on, so the rule borrows the bubble's own foreground.
              accent: isMine ? foreground : authorColor,
              foreground: muted,
              onTap: onJumpToOriginal,
            ),
          if (message.attachments.isNotEmpty)
            MessageAttachments(
              messageId: message.id,
              attachments: message.attachments,
              onOpen: onOpenAttachment,
              foreground: foreground,
            ),
          if (hasText)
            MessageText(
              content: content,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: foreground) ??
                  TextStyle(color: foreground),
              linkColor: isMine ? foreground : theme.colorScheme.primary,
              isKnownMention: isKnownMention,
              onOpenLink: onOpenLink,
            ),
          if (showMeta || message.isEdited)
            _MessageMeta(
              message: message,
              muted: muted,
              deliveryStatus: deliveryStatus,
              onTap: onShowDetails,
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
  }
}

/// The time, the edited mark and the ticks — and the way into the details.
class _MessageMeta extends StatelessWidget {
  const _MessageMeta({
    required this.message,
    required this.muted,
    required this.deliveryStatus,
    required this.onTap,
  });

  final MessageEntity message;
  final Color muted;
  final MessageDeliveryStatus? deliveryStatus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: onTap != null,
      label: onTap == null ? null : l10n.messageDetails,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Only above: the bubble's own padding closes the bottom, and the
          // extra sides give the tap target somewhere to be.
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatTime(message.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
              if (message.isEdited) ...[
                const SizedBox(width: 4),
                Text(
                  l10n.messageEdited,
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
        ),
      ),
    );
  }

  static String formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

/// What the server says about the conversation, not what anyone said in it.
class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.message, required this.onLongPress});

  final MessageEntity message;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.x2,
        horizontal: AppSpacing.x6,
      ),
      child: Center(
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3,
              vertical: AppSpacing.x1 + 1,
            ),
            decoration: BoxDecoration(
              color: chatix.dateChip,
              borderRadius: BorderRadius.circular(AppRadii.full),
            ),
            child: Text(
              message.content ?? '',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The checkbox lane that multi-select puts every message into.
class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    required this.isSelected,
    required this.onToggle,
    required this.child,
  });

  final bool isSelected;
  final VoidCallback? onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        color: isSelected
            ? scheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle?.call(),
            ),
            Expanded(child: child),
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
