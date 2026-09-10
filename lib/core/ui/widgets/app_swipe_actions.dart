import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

/// One button behind a swipeable row.
@immutable
class SwipeAction {
  const SwipeAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;

  /// Drawn under the icon and read out by screen readers, so it has to be a
  /// real sentence of its own — "Archive", not "arch".
  final String label;

  final Color background;
  final Color foreground;

  final VoidCallback onPressed;
}

/// A row that slides aside to show what can be done to it.
///
/// Dragging towards the end of the row reveals [trailing], dragging back
/// towards the start reveals [leading]; releasing past halfway leaves the
/// buttons open, and anything else springs the row back. The same actions are
/// expected to exist somewhere a pointer or a screen reader can reach them —
/// they are offered here as [CustomSemanticsAction]s, and a long-press menu is
/// the usual second home.
class AppSwipeActions extends StatefulWidget {
  const AppSwipeActions({
    super.key,
    required this.child,
    this.leading = const <SwipeAction>[],
    this.trailing = const <SwipeAction>[],
    this.actionExtent = 76,
    this.enabled = true,
  });

  final Widget child;

  /// Revealed by dragging towards the end of the row (leftwards in English).
  final List<SwipeAction> trailing;

  /// Revealed by dragging the other way.
  final List<SwipeAction> leading;

  /// Width of one button.
  final double actionExtent;

  final bool enabled;

  @override
  State<AppSwipeActions> createState() => _AppSwipeActionsState();
}

class _AppSwipeActionsState extends State<AppSwipeActions>
    with SingleTickerProviderStateMixin {
  /// Signed reveal in logical pixels: positive shows [AppSwipeActions.leading],
  /// negative shows [AppSwipeActions.trailing]. Unbounded so a drag can drive
  /// it directly and a release can animate it home.
  ///
  /// Built in [initState] rather than lazily: a row that is never dragged
  /// still has to be able to dispose of it, and building a ticker while the
  /// element is being torn down is too late to look one up.
  late final AnimationController _reveal;

  static const Duration _settle = Duration(milliseconds: 220);
  static const Curve _settleCurve = Curves.easeOutCubic;

  /// Past this, a flick decides the direction on its own.
  static const double _flingVelocity = 420;

  double get _leadingExtent => widget.leading.length * widget.actionExtent;

  double get _trailingExtent => widget.trailing.length * widget.actionExtent;

  bool get _isOpen => _reveal.value.abs() > 0.5;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController.unbounded(vsync: this);
  }

  @override
  void didUpdateWidget(covariant AppSwipeActions oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Losing the actions you were looking at (a chat that just became read,
    // say) should not leave the row parked open over nothing.
    if (!widget.enabled ||
        (widget.leading.isEmpty && _reveal.value > 0) ||
        (widget.trailing.isEmpty && _reveal.value < 0)) {
      _close();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double sign) {
    final delta = (details.primaryDelta ?? 0) * sign;
    _reveal.value = (_reveal.value + delta).clamp(
      -_trailingExtent,
      _leadingExtent,
    );
  }

  void _onDragEnd(DragEndDetails details, double sign) {
    final velocity = (details.primaryVelocity ?? 0) * sign;
    final value = _reveal.value;

    if (velocity.abs() > _flingVelocity) {
      _settleTo(velocity > 0 ? _leadingExtent : -_trailingExtent);
      return;
    }

    if (value > _leadingExtent / 2) {
      _settleTo(_leadingExtent);
    } else if (value < -_trailingExtent / 2) {
      _settleTo(-_trailingExtent);
    } else {
      _close();
    }
  }

  void _settleTo(double target) {
    if (target == _reveal.value) return;
    _reveal.animateTo(target, duration: _settle, curve: _settleCurve);
  }

  void _close() => _settleTo(0);

  void _run(SwipeAction action) {
    _close();
    action.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled ||
        (widget.leading.isEmpty && widget.trailing.isEmpty)) {
      return widget.child;
    }

    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

    return Semantics(
      customSemanticsActions: {
        for (final action in [...widget.leading, ...widget.trailing])
          CustomSemanticsAction(label: action.label): action.onPressed,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onHorizontalDragStart: (_) => _reveal.stop(),
        onHorizontalDragUpdate: (details) => _onDragUpdate(details, sign),
        onHorizontalDragEnd: (details) => _onDragEnd(details, sign),
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _reveal,
            builder: (context, child) {
              final value = _reveal.value;

              return Stack(
                children: [
                  if (value > 0)
                    _pane(
                      actions: widget.leading,
                      extent: _leadingExtent,
                      dx: (value - _leadingExtent) * sign,
                      atStart: true,
                    ),
                  if (value < 0)
                    _pane(
                      actions: widget.trailing,
                      extent: _trailingExtent,
                      dx: (_trailingExtent + value) * sign,
                      atStart: false,
                    ),
                  Transform.translate(
                    offset: Offset(value * sign, 0),
                    child: _isOpen
                        ? Stack(
                            children: [
                              child!,
                              // While the buttons are out, a tap on the row
                              // puts them away instead of opening the chat.
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _close,
                                ),
                              ),
                            ],
                          )
                        : child,
                  ),
                ],
              );
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _pane({
    required List<SwipeAction> actions,
    required double extent,
    required double dx,
    required bool atStart,
  }) {
    return PositionedDirectional(
      top: 0,
      bottom: 0,
      start: atStart ? 0 : null,
      end: atStart ? null : 0,
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: SizedBox(
          width: extent,
          child: Row(
            children: [
              for (final action in actions)
                SizedBox(
                  width: widget.actionExtent,
                  child: _SwipeActionButton(
                    action: action,
                    onPressed: () => _run(action),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({required this.action, required this.onPressed});

  final SwipeAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: action.background,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, size: 20, color: action.foreground),
              const SizedBox(height: 4),
              // Two lines rather than an ellipsis: a button whose label is
              // cut in half is a button you have to guess at.
              Text(
                action.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: action.foreground,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
