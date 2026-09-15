import 'package:flutter/material.dart';

/// Tells its child how much of it the reader can actually see.
///
/// There is no framework hook for this and no package for it here, so it is
/// measured: the child's rectangle against the nearest scrollable's
/// viewport, re-taken whenever that scrollable moves and once after every
/// layout. A widget inside a list cannot listen for the list's scroll
/// notifications — those travel up from the [Scrollable] and the child is
/// underneath it — so the [ScrollPosition] itself is what is listened to.
///
/// [onVisibilityChanged] is called with the visible fraction of the child's
/// area, `[0, 1]`, and only when that fraction actually changes by more than
/// [resolution] — a list being flung would otherwise call it on every frame
/// with a number nobody acts on differently.
class ViewportVisibility extends StatefulWidget {
  const ViewportVisibility({
    super.key,
    required this.onVisibilityChanged,
    required this.child,
    this.resolution = 0.05,
  });

  final ValueChanged<double> onVisibilityChanged;

  /// How much the fraction has to move before it is worth reporting. 0 and 1
  /// are always reported, whatever this is: fully gone and fully arrived are
  /// the two readings anything actually switches on.
  final double resolution;

  final Widget child;

  @override
  State<ViewportVisibility> createState() => _ViewportVisibilityState();
}

class _ViewportVisibilityState extends State<ViewportVisibility> {
  ScrollPosition? _position;
  double? _reported;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_schedule);
      _position = position;
      _position?.addListener(_schedule);
    }

    _schedule();
  }

  @override
  void dispose() {
    _position?.removeListener(_schedule);
    super.dispose();
  }

  /// Measuring during a scroll callback would read a layout that is being
  /// rewritten, so every measurement waits for the frame it belongs to.
  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    final fraction = _visibleFraction();
    final last = _reported;

    final worthSaying =
        last == null ||
        (fraction - last).abs() >= widget.resolution ||
        (fraction == 0 && last != 0) ||
        (fraction == 1 && last != 1);

    if (!worthSaying) return;

    _reported = fraction;
    widget.onVisibilityChanged(fraction);
  }

  double _visibleFraction() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return 0;

    final area = box.size.width * box.size.height;
    if (area <= 0) return 0;

    final rect = box.localToGlobal(Offset.zero) & box.size;
    final bounds = _viewportRect();

    final overlapWidth =
        (rect.right.clamp(bounds.left, bounds.right) -
                rect.left.clamp(bounds.left, bounds.right))
            .clamp(0.0, rect.width);
    final overlapHeight =
        (rect.bottom.clamp(bounds.top, bounds.bottom) -
                rect.top.clamp(bounds.top, bounds.bottom))
            .clamp(0.0, rect.height);

    return ((overlapWidth * overlapHeight) / area).clamp(0.0, 1.0);
  }

  /// What counts as "on screen": the scrollable this sits in, or the window
  /// when it sits in none.
  Rect _viewportRect() {
    final scrollable = Scrollable.maybeOf(context);
    final viewport = scrollable?.context.findRenderObject();

    if (viewport is RenderBox && viewport.attached && viewport.hasSize) {
      return viewport.localToGlobal(Offset.zero) & viewport.size;
    }

    final view = View.of(context);
    return Offset.zero & (view.physicalSize / view.devicePixelRatio);
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    return widget.child;
  }
}
