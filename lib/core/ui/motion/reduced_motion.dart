import 'package:flutter/material.dart';

/// Reading the platform's "reduce motion" switch, in one place.
///
/// The flag reaches the app as `MediaQuery.disableAnimations` — set by the
/// OS, and mirrored onto the tree by `AccessibilityWrapper` so an in-app
/// reading of the same setting cannot disagree with it. Everything that
/// animates asks here rather than reaching for the media query itself, so
/// that "what reduced motion means" is a decision made once:
///
/// * a transition **degenerates to a cross-fade**, or to nothing at all — it
///   is not merely made smaller. A shorter slide is still a slide, and the
///   people who turn this on are not asking for a subtler version;
/// * anything **ambient** — a parallax, a looping shimmer, drifting
///   particles — stops entirely, because nothing was asking for it;
/// * anything **informational** still moves if standing still would lose the
///   information: a progress ring keeps turning, a countdown keeps counting.
extension ReducedMotion on BuildContext {
  /// Whether the reader has asked for less movement.
  ///
  /// `maybe` rather than the plain accessor: widgets are rendered in test
  /// harnesses and in `showDialog` builders where there may be no
  /// `MediaQuery` above them, and the honest answer there is "no preference
  /// expressed" rather than a crash.
  bool get prefersReducedMotion =>
      MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// [duration], or nothing at all when motion is reduced.
  ///
  /// The animation still runs — implicit widgets rebuild, callbacks still
  /// fire, `AnimatedList` still reindexes — it simply arrives in one frame.
  /// That is what keeps a reduced-motion pass from turning into a second,
  /// untested set of code paths.
  Duration motion(Duration duration) =>
      prefersReducedMotion ? Duration.zero : duration;

  /// [curve], or a linear one when there is no time left to curve over.
  Curve motionCurve(Curve curve) =>
      prefersReducedMotion ? Curves.linear : curve;
}
