import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'package:chatix/core/theme/app_tokens.dart';

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
  late final AnimationController _offset;

  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 26,
  );

  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _offset = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool get _active => widget.enabled && widget.onReply != null;

  void _onUpdate(DragUpdateDetails details) {
    final next = _resist(_offset.value + details.delta.dx);
    _offset.value = next;

    final armed = next >= widget.threshold;
    if (armed == _armed) return;

    _armed = armed;
    // Only on the way in: a haptic on every crossing turns a wobble at the
    // threshold into a burst of buzzing.
    if (armed) HapticFeedback.selectionClick();
  }

  /// Past the threshold the message keeps moving, but a third as fast, so the
  /// drag has an obvious ceiling without hitting a hard stop.
  double _resist(double raw) {
    if (raw <= 0) return 0;
    if (raw <= widget.threshold) return raw;

    final over = raw - widget.threshold;
    final room = widget.maxDrag - widget.threshold;
    return widget.threshold + room * (1 - 1 / (1 + over / room));
  }

  void _onEnd(DragEndDetails details) {
    if (_armed) widget.onReply?.call();
    _armed = false;
    _settle(details.velocity.pixelsPerSecond.dx);
  }

  void _settle(double velocity) {
    if (_offset.value == 0) return;
    _offset.animateWith(
      SpringSimulation(_spring, _offset.value, 0, velocity.clamp(-4000, 4000)),
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
        animation: _offset,
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
              Transform.translate(
                offset: Offset(travel, 0),
                child: child,
              ),
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
