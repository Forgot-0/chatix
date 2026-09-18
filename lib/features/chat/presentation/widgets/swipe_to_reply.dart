import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/haptics.dart';
import 'package:chatix/core/ui/motion/motion.dart';

/// Drag a message sideways to reply to it.
///
/// The drag is rubber-banded past the trigger point, fires a haptic the
/// moment it arms (once, not on every frame), and springs back when let go —
/// the spring is what makes the gesture feel attached to the finger rather
/// than animated at it.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.child,
    this.onReply,
    this.enabled = true,
    this.threshold = 44,
    this.maxDrag = 72,
    this.icon = Icons.reply,
  });

  final Widget child;

  /// Called once, on release, if the drag got past [threshold]. A null
  /// callback disables the gesture — there is nothing to reply to.
  final VoidCallback? onReply;

  final bool enabled;

  /// How far the message must travel before the gesture arms.
  final double threshold;

  /// The furthest it will travel, however hard it is pulled.
  final double maxDrag;

  final IconData icon;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  // Built in initState rather than lazily: a message that never gets dragged
  // would otherwise create its ticker inside dispose(), which is too late to
  // look up the TickerMode above it.
  late final GestureSpring _offset;

  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _offset = GestureSpring(vsync: this);
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool get _active => widget.enabled && widget.onReply != null;

  void _onUpdate(DragUpdateDetails details) {
    // Rubber-banded past the trigger point: the message keeps following the
    // finger, with diminishing returns, so the gesture has an obvious
    // ceiling without hitting a hard stop.
    _offset.drag(
      details.delta.dx,
      threshold: widget.threshold,
      limit: widget.maxDrag,
    );

    final armed = _offset.value >= widget.threshold;
    if (armed == _armed) return;

    _armed = armed;
    // Only on the way in: a haptic on every crossing turns a wobble at the
    // threshold into a burst of buzzing.
    if (armed) AppHaptics.gestureThreshold();
  }

  void _onEnd(DragEndDetails details) {
    if (_armed) widget.onReply?.call();
    _armed = false;
    _settle(details.velocity.pixelsPerSecond.dx);
  }

  void _settle(double velocity) {
    _offset.settle(
      velocity: velocity,
      // A spring is a rubber band snapping back. With reduced motion on, the
      // message simply is where it was before the drag.
      reducedMotion: context.prefersReducedMotion,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;

    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: () {
        _armed = false;
        _settle(0);
      },
      child: AnimatedBuilder(
        animation: _offset.animation,
        builder: (context, child) {
          final travel = _offset.value.clamp(0.0, widget.maxDrag);
          final progress = (travel / widget.threshold).clamp(0.0, 1.0);

          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (travel > 0)
                Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: 0.7 + 0.3 * progress,
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color: progress == 1 ? scheme.primary : scheme.outline,
                    ),
                  ),
                ),
              Transform.translate(offset: Offset(travel, 0), child: child),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// The travel a reply gesture uses, exposed so a list can leave room for the
/// icon it slides over.
const double kSwipeToReplyGutter = AppSpacing.x6;
