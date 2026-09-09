import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// The two Material motion patterns the app navigates with.
///
/// * **Shared axis (horizontal)** — a push that moves *forward* in a hierarchy:
///   opening a chat, its members, its info. The outgoing screen slides out and
///   fades while the incoming one slides in behind it, so the two read as
///   neighbours on one axis.
/// * **Fade through** — a swap between destinations that have no spatial
///   relationship: the tab bar's branches. Nothing slides, because there is no
///   direction to travel in.
///
/// Both honour `MediaQuery.disableAnimations`: with reduced motion on, the
/// child is handed back untransformed rather than being animated more subtly —
/// a smaller animation is still an animation.
abstract final class AppPageTransitions {
  /// Distance the shared-axis pair travels, as a fraction of the viewport.
  ///
  /// Material specifies 30dp; expressed as a fraction so the gesture keeps its
  /// proportions on a phone and on a tablet pane.
  static const double _slideFraction = 0.12;

  /// The incoming half starts only once the outgoing half has faded, so the
  /// two never cross-dissolve into a muddy double image.
  static const Interval _incomingFade = Interval(0.3, 1);
  static const Interval _outgoingFade = Interval(0, 0.3);

  static const Duration duration = AppMotion.slow;

  /// Forward navigation inside a section: chat list → chat → members.
  static CustomTransitionPage<T> sharedAxisHorizontal<T>({
    required LocalKey key,
    required Widget child,
    String? name,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: buildSharedAxisHorizontal,
    );
  }

  /// A lateral swap: same level of the hierarchy, no direction implied.
  static CustomTransitionPage<T> fadeThrough<T>({
    required LocalKey key,
    required Widget child,
    String? name,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      child: child,
      transitionDuration: AppMotion.base,
      reverseTransitionDuration: AppMotion.base,
      transitionsBuilder: buildFadeThrough,
    );
  }

  /// Exposed separately so a `Navigator` outside go_router — a dialog route, a
  /// test harness — can reuse the same motion.
  static Widget buildSharedAxisHorizontal(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_prefersReducedMotion(context)) return child;

    // Right-to-left languages travel the other way: "forward" follows the
    // reading direction, not the physical x axis.
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

    return SlideTransition(
      position:
          Tween<Offset>(
            begin: Offset(_slideFraction * sign, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: AppMotion.curve,
              reverseCurve: AppMotion.reverseCurve,
            ),
          ),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: _incomingFade),
        child: SlideTransition(
          position:
              Tween<Offset>(
                begin: Offset.zero,
                end: Offset(-_slideFraction * sign, 0),
              ).animate(
                CurvedAnimation(
                  parent: secondaryAnimation,
                  curve: AppMotion.curve,
                  reverseCurve: AppMotion.reverseCurve,
                ),
              ),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(
              CurvedAnimation(parent: secondaryAnimation, curve: _outgoingFade),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  static Widget buildFadeThrough(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_prefersReducedMotion(context)) return child;

    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: _incomingFade),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(
          CurvedAnimation(parent: animation, curve: AppMotion.curve),
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(
            CurvedAnimation(parent: secondaryAnimation, curve: _outgoingFade),
          ),
          child: child,
        ),
      ),
    );
  }

  static bool _prefersReducedMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// The fade-through's incoming half, for content that swaps in place.
///
/// The tab branches live in an `IndexedStack` that keeps every branch mounted —
/// that is what preserves each tab's scroll position and navigation stack — so
/// there is no outgoing widget left to fade out: by the time this rebuilds, the
/// stack has already switched. What is left is the half that carries the
/// pattern's character, the incoming fade with its slight scale up.
class FadeThroughSwitcher extends StatefulWidget {
  const FadeThroughSwitcher({
    super.key,
    required this.switchKey,
    required this.child,
  });

  /// Changing this replays the transition. Typically the selected tab index.
  final Object switchKey;

  final Widget child;

  @override
  State<FadeThroughSwitcher> createState() => _FadeThroughSwitcherState();
}

class _FadeThroughSwitcherState extends State<FadeThroughSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.base,
    // Settled, so the first frame of the app is not a fade from nothing.
    value: 1,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.curve,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.94,
    end: 1,
  ).animate(_fade);

  @override
  void didUpdateWidget(FadeThroughSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.switchKey != oldWidget.switchKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
