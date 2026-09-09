import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';

/// Draws the face of one of the people behind a reaction.
///
/// The chip only knows user ids (`ReactionGroupDTO.recent_user_ids`), never
/// profiles, so a screen that has the roster loaded can pass a real avatar
/// and one that does not still gets the person's identity colour.
typedef ReactionFaceBuilder =
    Widget Function(BuildContext context, int userId, double size);

/// One emoji on a message: the emoji, how many people picked it, and the
/// first few of them.
class ReactionChip extends StatelessWidget {
  const ReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    this.selected = false,
    this.recentUserIds = const <int>[],
    this.faceBuilder,
    this.onTap,
    this.onLongPress,
    this.onSurface = false,
  });

  final String emoji;

  final int count;

  /// Whether this reaction includes your own (`reacted_by_me`).
  final bool selected;

  /// `recent_user_ids` from the reaction group. At most [maxFaces] are drawn.
  final List<int> recentUserIds;

  final ReactionFaceBuilder? faceBuilder;

  final VoidCallback? onTap;

  /// Opens the "who reacted" sheet.
  final VoidCallback? onLongPress;

  /// True when the chip sits on the outgoing gradient rather than on a
  /// surface; the fills go translucent-white so they read on the accent.
  final bool onSurface;

  static const int maxFaces = 3;
  static const double _faceSize = 16;
  static const double _faceOverlap = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chatix = ChatixTheme.of(context);

    final accent = onSurface ? Colors.white : scheme.primary;
    final idle = onSurface
        ? Colors.white.withValues(alpha: 0.72)
        : scheme.outline;

    final fill = onSurface
        ? Colors.white.withValues(alpha: selected ? 0.26 : 0.14)
        : (selected ? chatix.reactionChipSelected : chatix.reactionChip);

    final faces = recentUserIds.take(maxFaces).toList();

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '$emoji $count',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadii.full),
        // The emoji and the digits are already in the label above; excluding
        // them here keeps the node to one reading without taking the tap
        // action away from the ink well.
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x2,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppRadii.full),
              border: Border.all(color: selected ? accent : Colors.transparent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: theme.textTheme.bodySmall),
                const SizedBox(width: AppSpacing.x1),
                _AnimatedCount(
                  count: count,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? accent : idle,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (faces.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.x1),
                  _Faces(
                    userIds: faces,
                    builder: faceBuilder,
                    size: _faceSize,
                    overlap: _faceOverlap,
                    ringColor: fill,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The count, and only the count, animates.
///
/// Reactions change constantly under a busy message; re-running an entrance
/// on the whole chip would make the row jitter, so the digits slide in the
/// direction they moved and everything around them holds still.
class _AnimatedCount extends StatefulWidget {
  const _AnimatedCount({required this.count, this.style});

  final int count;
  final TextStyle? style;

  @override
  State<_AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<_AnimatedCount> {
  bool _rising = true;

  @override
  void didUpdateWidget(_AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) {
      _rising = widget.count > oldWidget.count;
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = Offset(0, _rising ? 0.6 : -0.6);

    return AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.curve,
      switchOutCurve: AppMotion.curve,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: from,
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      // Sized so the row does not reflow while the two digits cross over.
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.center, children: [...previous, ?current]),
      child: Text(
        '${widget.count}',
        key: ValueKey<int>(widget.count),
        style: widget.style,
      ),
    );
  }
}

class _Faces extends StatelessWidget {
  const _Faces({
    required this.userIds,
    required this.builder,
    required this.size,
    required this.overlap,
    required this.ringColor,
  });

  final List<int> userIds;
  final ReactionFaceBuilder? builder;
  final double size;
  final double overlap;

  /// The chip's own fill, painted as a ring so overlapping faces separate.
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final chatix = ChatixTheme.of(context);
    final step = size - overlap;

    return SizedBox(
      width: size + step * (userIds.length - 1),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < userIds.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: chatix.authorColor(userIds[i]),
                  border: Border.all(color: ringColor, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: builder?.call(context, userIds[i], size),
              ),
            ),
        ],
      ),
    );
  }
}
