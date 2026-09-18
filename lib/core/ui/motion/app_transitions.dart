import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/motion/reduced_motion.dart';

/// The app's three transitions, as plain builders.
///
/// Three, not thirty: a transition is a sentence about how two things are
/// related, and there are only three relations worth drawing here.
///
/// * **[sharedAxisX]** — *forward and back along one axis.* A push inside a
///   hierarchy: chat list → chat → members. The pair travels together, so the
///   two screens read as neighbours and the back gesture reads as a return.
/// * **[fadeThrough]** — *no spatial relation at all.* A swap between peers:
///   the tab bar's branches, a filtered list changing what it is listing.
///   Nothing slides, because there is no direction to slide in.
/// * **[scaleIn]** — *arriving on top of what is already there.* A sheet, an
///   overlay, a viewer: it grows out of the surface rather than travelling
///   in from off screen.
///
/// Every one of them honours reduced motion by degenerating to a cross-fade
/// (or to nothing for the outgoing half), never to a smaller version of
/// itself — see [ReducedMotion].
///
/// The route-shaped builders here match `RouteTransitionsBuilder`, so they
/// can be handed to go_router, to a bare `PageRouteBuilder` or to a test
/// harness unchanged. The switcher-shaped ones on [AppSwitcherTransitions]
/// match `AnimatedSwitcher.transitionBuilder`.
abstract final class AppTransitions {
  /// Distance the shared-axis pair travels, as a fraction of the viewport.
  ///
  /// Material specifies 30dp; expressed as a fraction so the gesture keeps
  /// its proportions on a phone and in a tablet pane.
  static const double slideFraction = 0.12;

  /// How far a scaling arrival starts from its final size.
  static const double scaleFrom = 0.92;

  /// The incoming half starts only once the outgoing half has faded, so the
  /// two never cross-dissolve into a muddy double image.
  static const Interval incomingFade = Interval(0.3, 1);
  static const Interval outgoingFade = Interval(0, 0.3);

  /// Forward navigation inside a section: chat list → chat → members.
  static Widget sharedAxisX(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context.prefersReducedMotion) {
      return _crossFade(animation, secondaryAnimation, child);
    }

    // Right-to-left languages travel the other way: "forward" follows the
    // reading direction, not the physical x axis.
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

    return SlideTransition(
      position:
          Tween<Offset>(
            begin: Offset(slideFraction * sign, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: AppMotion.curve,
              reverseCurve: AppMotion.reverseCurve,
            ),
          ),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: incomingFade),
        child: SlideTransition(
          position:
              Tween<Offset>(
                begin: Offset.zero,
                end: Offset(-slideFraction * sign, 0),
              ).animate(
                CurvedAnimation(
                  parent: secondaryAnimation,
                  curve: AppMotion.curve,
                  reverseCurve: AppMotion.reverseCurve,
                ),
              ),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(
              CurvedAnimation(parent: secondaryAnimation, curve: outgoingFade),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  /// A lateral swap: same level of the hierarchy, no direction implied.
  static Widget fadeThrough(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context.prefersReducedMotion) {
      return _crossFade(animation, secondaryAnimation, child);
    }

    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: incomingFade),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: scaleFrom,
          end: 1,
        ).animate(CurvedAnimation(parent: animation, curve: AppMotion.curve)),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(
            CurvedAnimation(parent: secondaryAnimation, curve: outgoingFade),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Something arriving on top of what is already there.
  ///
  /// The page below keeps being painted — this is the transition for routes
  /// that are not opaque — so the arrival grows out of it rather than
  /// replacing it.
  static Widget scaleIn(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context.prefersReducedMotion) {
      return FadeTransition(opacity: animation, child: child);
    }

    final eased = CurvedAnimation(
      parent: animation,
      curve: AppMotion.curve,
      reverseCurve: AppMotion.reverseCurve,
    );

    return FadeTransition(
      opacity: eased,
      child: ScaleTransition(
        scale: Tween<double>(begin: scaleFrom, end: 1).animate(eased),
        child: child,
      ),
    );
  }

  /// What every transition becomes when motion is reduced: the incoming page
  /// fades up, the outgoing one is simply gone.
  static Widget _crossFade(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(secondaryAnimation),
        child: child,
      ),
    );
  }
}

/// The same three, shaped for [AnimatedSwitcher] and [MotionSwitcher].
///
/// A switcher has only the one animation — it runs forward for the arriving
/// child and in reverse for the leaving one — so these are the incoming
/// halves of the patterns above, which is the half that carries their
/// character.
abstract final class AppSwitcherTransitions {
  static Widget fadeThrough(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: AppTransitions.incomingFade,
      ),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: AppTransitions.scaleFrom,
          end: 1,
        ).animate(CurvedAnimation(parent: animation, curve: AppMotion.curve)),
        child: child,
      ),
    );
  }

  static Widget scaleIn(Widget child, Animation<double> animation) {
    final eased = CurvedAnimation(
      parent: animation,
      curve: AppMotion.curve,
      reverseCurve: AppMotion.reverseCurve,
    );

    return FadeTransition(
      opacity: eased,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: AppTransitions.scaleFrom,
          end: 1,
        ).animate(eased),
        child: child,
      ),
    );
  }

  /// The incoming half of the shared axis: in from the leading edge.
  ///
  /// Direction-aware like its route-level twin, which is why it needs the
  /// context the other two do not.
  static AnimatedSwitcherTransitionBuilder sharedAxisX(BuildContext context) {
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

    return (child, animation) => SlideTransition(
      position:
          Tween<Offset>(
            begin: Offset(AppTransitions.slideFraction * sign, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: AppMotion.curve,
              reverseCurve: AppMotion.reverseCurve,
            ),
          ),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// A plain cross-fade — what the others become under reduced motion.
  static Widget fade(Widget child, Animation<double> animation) =>
      FadeTransition(opacity: animation, child: child);
}

/// Which of the patterns a [MotionSwitcher] swaps its child with.
enum MotionPattern {
  /// Peers replacing each other in place.
  fadeThrough,

  /// Something arriving on top.
  scaleIn,

  /// A step along a hierarchy, drawn inside one box.
  sharedAxisX;

  Duration get duration => switch (this) {
    MotionPattern.fadeThrough => AppMotion.base,
    MotionPattern.scaleIn => AppMotion.base,
    MotionPattern.sharedAxisX => AppMotion.slow,
  };
}

/// [AnimatedSwitcher] wired to the app's patterns and to reduced motion.
///
/// Prefer this to a bare `AnimatedSwitcher`: it is the difference between
/// every swap in the app agreeing on how long a swap takes and thirty
/// widgets each having an opinion.
class MotionSwitcher extends StatelessWidget {
  const MotionSwitcher({
    super.key,
    required this.child,
    this.pattern = MotionPattern.fadeThrough,
    this.alignment = Alignment.center,
    this.duration,
  });

  /// Keyed by whatever should count as "a different thing" — swapping a
  /// child with the same key animates nothing, which is usually what a
  /// rebuild wants.
  final Widget child;

  final MotionPattern pattern;

  final AlignmentGeometry alignment;

  /// Overrides [MotionPattern.duration]. Still a token, still collapses to
  /// zero under reduced motion.
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final reduced = context.prefersReducedMotion;
    final length = duration ?? pattern.duration;

    return AnimatedSwitcher(
      duration: context.motion(length),
      reverseDuration: context.motion(AppMotion.fast),
      switchInCurve: AppMotion.curve,
      switchOutCurve: AppMotion.reverseCurve,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: <Widget>[...previous, ?current],
      ),
      transitionBuilder: reduced
          ? AppSwitcherTransitions.fade
          : switch (pattern) {
              MotionPattern.fadeThrough => AppSwitcherTransitions.fadeThrough,
              MotionPattern.scaleIn => AppSwitcherTransitions.scaleIn,
              MotionPattern.sharedAxisX => AppSwitcherTransitions.sharedAxisX(
                context,
              ),
            },
      child: child,
    );
  }
}

/// The fade-through's incoming half, for content that swaps in place.
///
/// The tab branches live in an `IndexedStack` that keeps every branch
/// mounted — that is what preserves each tab's scroll position and
/// navigation stack — so there is no outgoing widget left to fade out: by the
/// time this rebuilds, the stack has already switched. What is left is the
/// half that carries the pattern's character, the incoming fade with its
/// slight scale up.
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
    begin: AppTransitions.scaleFrom,
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
    if (context.prefersReducedMotion) return widget.child;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
