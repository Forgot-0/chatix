import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/desktop/desktop_input.dart';

/// The app's scroll behaviour: Material's, with scrollbars a desktop reader
/// can see.
///
/// On macOS, Windows and Linux every vertical list carries a thin thumb
/// that is always there — where you are in a long chat or a long settings
/// page is worth knowing before you start scrolling — and that widens into
/// a grip under the pointer. Horizontal strips (chips, folder tabs) stay
/// bare, as Material leaves them; a phone keeps Material's own behaviour.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (!DesktopInput.isDesktop) {
      return super.buildScrollbar(context, child, details);
    }

    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        return Scrollbar(
          controller: details.controller,
          thumbVisibility: true,
          child: child,
        );
    }
  }
}

/// A [ScrollController] whose mouse wheel glides instead of jumping.
///
/// A wheel notch arrives as one jump of a hundred-odd pixels; in a feed of
/// bubbles that reads as the whole conversation stuttering. Here each notch
/// sets a target and the list eases to it over [AppMotion.wheel], with
/// notches that arrive mid-glide adding up rather than restarting from
/// wherever the list happened to be. Trackpads are left alone: they already
/// scroll pixel by pixel, through a different kind of event.
///
/// Works for reversed lists as they are — the scrollable has already turned
/// the wheel's direction into the list's by the time the delta gets here.
class SmoothWheelScrollController extends ScrollController {
  SmoothWheelScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  /// Off where motion is reduced: a notch is then the jump it always was.
  bool smooth = true;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SmoothWheelScrollPosition(
      controller: this,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _SmoothWheelScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothWheelScrollPosition({
    required this.controller,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final SmoothWheelScrollController controller;

  /// Where the glide in progress is heading; null when there is none.
  double? _target;

  @override
  void pointerScroll(double delta) {
    if (!controller.smooth || delta == 0) {
      _target = null;
      super.pointerScroll(delta);
      return;
    }

    final from = _target ?? pixels;
    final target = (from + delta).clamp(minScrollExtent, maxScrollExtent);
    if (target == from) return;

    _target = target;
    animateTo(
      target,
      duration: AppMotion.wheel,
      curve: AppMotion.curve,
    ).whenComplete(() {
      if (_target == target) _target = null;
    });
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    // A drag, a fling or a jump of the code's own takes over from the
    // glide, and the next notch starts from where the list really is.
    if (newActivity is! DrivenScrollActivity) _target = null;
    super.beginActivity(newActivity);
  }
}
