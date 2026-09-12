import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/utils/message_actions.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What the caller gets back when the menu closes.
class MessageActionsResult {
  const MessageActionsResult.action(this.action) : emoji = null;
  const MessageActionsResult.reaction(this.emoji) : action = null;

  final MessageAction? action;

  /// Set when the quick-reaction bar was used instead of the list.
  final String? emoji;
}

/// The long-press menu: the conversation goes out of focus, the message
/// stays.
///
/// The bubble itself is lifted out of the list and redrawn over the blur at
/// the place it already occupied, so there is never a moment where the reader
/// has to find which message they pressed. Reactions sit above it because
/// that is a single tap and the most common answer; the list of actions sits
/// below, where a thumb already is.
abstract final class MessageActionsOverlay {
  /// Opens over the whole app. [anchor] is the bubble's place on screen, in
  /// global coordinates, and [bubble] is what to redraw there.
  static Future<MessageActionsResult?> show(
    BuildContext context, {
    required Rect anchor,
    required Widget bubble,
    required List<MessageAction> actions,
    required List<String> reactions,
    required Set<String> myReactions,
    required bool isMine,
  }) {
    return Navigator.of(context, rootNavigator: true).push<MessageActionsResult>(
      PageRouteBuilder<MessageActionsResult>(
        opaque: false,
        barrierDismissible: true,
        barrierLabel: AppLocalizations.of(context).close,
        transitionDuration: AppMotion.base,
        reverseTransitionDuration: AppMotion.fast,
        pageBuilder: (routeContext, animation, _) => _MessageActionsLayer(
          animation: animation,
          anchor: anchor,
          bubble: bubble,
          actions: actions,
          reactions: reactions,
          myReactions: myReactions,
          isMine: isMine,
        ),
      ),
    );
  }
}

class _MessageActionsLayer extends StatelessWidget {
  const _MessageActionsLayer({
    required this.animation,
    required this.anchor,
    required this.bubble,
    required this.actions,
    required this.reactions,
    required this.myReactions,
    required this.isMine,
  });

  final Animation<double> animation;
  final Rect anchor;
  final Widget bubble;
  final List<MessageAction> actions;
  final List<String> reactions;
  final Set<String> myReactions;
  final bool isMine;

  static const double _gap = AppSpacing.x3;
  static const double _reactionBar = 52;
  static const double _actionRow = 46;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safe = media.padding;
    final size = media.size;

    final showsReactions = reactions.isNotEmpty;
    final reactionsHeight = showsReactions ? _reactionBar + _gap : 0.0;
    final menuHeight = actions.length * _actionRow + AppSpacing.x2 * 2;

    final topLimit = safe.top + AppSpacing.x3 + reactionsHeight;
    final bottomLimit = size.height - safe.bottom - AppSpacing.x3 - menuHeight -
        _gap;

    // How tall the bubble may be before the panels have nowhere to go. A
    // message longer than that scrolls inside its own copy rather than
    // pushing the actions off screen.
    final maxBubbleHeight = math.max(120.0, bottomLimit - topLimit);
    final bubbleHeight = math.min(anchor.height, maxBubbleHeight);

    // Stay where the message already is, and only move as far as the panels
    // demand.
    final restingTop = anchor.top
        .clamp(topLimit, math.max(topLimit, bottomLimit - bubbleHeight))
        .toDouble();

    final curve = CurvedAnimation(
      parent: animation,
      curve: AppMotion.curve,
      reverseCurve: AppMotion.reverseCurve,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: _Scrim(animation: curve),
            ),
          ),
          AnimatedBuilder(
            animation: curve,
            builder: (context, _) {
              final t = curve.value;
              final top = lerpDouble(anchor.top, restingTop, t);

              return Stack(
                children: [
                  if (showsReactions)
                    Positioned(
                      left: AppSpacing.x3,
                      right: AppSpacing.x3,
                      top: top - reactionsHeight,
                      child: Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: _PanelIn(
                          t: t,
                          fromBelow: true,
                          child: _QuickReactionBar(
                            reactions: reactions,
                            mine: myReactions,
                            onSelected: (emoji) => Navigator.of(context).pop(
                              MessageActionsResult.reaction(emoji),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: anchor.left,
                    width: anchor.width,
                    top: top,
                    height: bubbleHeight,
                    child: IgnorePointer(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: bubble,
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.x3,
                    right: AppSpacing.x3,
                    top: top + bubbleHeight + _gap,
                    child: Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: _PanelIn(
                        t: t,
                        fromBelow: false,
                        child: _ActionList(
                          actions: actions,
                          onSelected: (action) => Navigator.of(context).pop(
                            MessageActionsResult.action(action),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// The conversation, pushed out of focus.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18 * t, sigmaY: 18 * t),
          child: ColoredBox(
            color: (isDark ? Colors.black : Colors.black).withValues(
              alpha: (isDark ? 0.45 : 0.25) * t,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

/// A panel arriving towards the bubble it belongs to.
class _PanelIn extends StatelessWidget {
  const _PanelIn({
    required this.t,
    required this.fromBelow,
    required this.child,
  });

  final double t;

  /// The reactions rise from the bubble, the actions drop from it — both
  /// move away from the message, which is what ties them to it.
  final bool fromBelow;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (fromBelow ? 1 : -1) * 12 * (1 - t)),
        child: Transform.scale(
          scale: 0.92 + 0.08 * t,
          alignment: fromBelow ? Alignment.bottomCenter : Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }
}

class _QuickReactionBar extends StatelessWidget {
  const _QuickReactionBar({
    required this.reactions,
    required this.mine,
    required this.onSelected,
  });

  final List<String> reactions;
  final Set<String> mine;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHigh,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(AppRadii.full),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - AppSpacing.x6,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final emoji in reactions)
                _QuickReaction(
                  emoji: emoji,
                  isMine: mine.contains(emoji),
                  onTap: () => onSelected(emoji),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickReaction extends StatelessWidget {
  const _QuickReaction({
    required this.emoji,
    required this.isMine,
    required this.onTap,
  });

  final String emoji;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: isMine,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 2,
            vertical: AppSpacing.x1,
          ),
          padding: const EdgeInsets.all(AppSpacing.x2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMine
                ? scheme.primary.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

class _ActionList extends StatelessWidget {
  const _ActionList({required this.actions, required this.onSelected});

  final List<MessageAction> actions;
  final ValueChanged<MessageAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHigh,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 212, maxWidth: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.x2),
            for (final action in actions)
              _ActionRow(
                action: action,
                label: labelOf(action, l10n),
                icon: iconOf(action),
                isDestructive: action == MessageAction.delete,
                destructiveColor: chatix.danger,
                onTap: () => onSelected(action),
              ),
            const SizedBox(height: AppSpacing.x2),
          ],
        ),
      ),
    );
  }

  static String labelOf(MessageAction action, AppLocalizations l10n) =>
      switch (action) {
        MessageAction.reply => l10n.messageReply,
        MessageAction.react => l10n.messageReact,
        MessageAction.copy => l10n.messageCopy,
        MessageAction.forward => l10n.messageForward,
        MessageAction.edit => l10n.messageEdit,
        MessageAction.select => l10n.messageSelect,
        MessageAction.delete => l10n.messageDelete,
        MessageAction.details => l10n.messageDetails,
      };

  static IconData iconOf(MessageAction action) => switch (action) {
    MessageAction.reply => Icons.reply,
    MessageAction.react => Icons.add_reaction_outlined,
    MessageAction.copy => Icons.copy_all_outlined,
    MessageAction.forward => Icons.shortcut,
    MessageAction.edit => Icons.edit_outlined,
    MessageAction.select => Icons.checklist,
    MessageAction.delete => Icons.delete_outline,
    MessageAction.details => Icons.info_outline,
  };
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.label,
    required this.icon,
    required this.isDestructive,
    required this.destructiveColor,
    required this.onTap,
  });

  final MessageAction action;
  final String label;
  final IconData icon;
  final bool isDestructive;
  final Color destructiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? destructiveColor
        : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
            const SizedBox(width: AppSpacing.x4),
            Icon(icon, size: 19, color: color),
          ],
        ),
      ),
    );
  }
}
