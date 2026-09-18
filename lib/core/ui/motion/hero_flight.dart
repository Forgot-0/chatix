import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// Hero flights whose corners travel with them.
///
/// A [Hero] lifts its child out of the tree and into the navigator's overlay
/// for the duration of the flight, which leaves every ancestor behind —
/// including the `ClipRRect` that was rounding it. The default flight of a
/// rounded thumbnail into a full-bleed viewer therefore goes square on the
/// first frame, flies, and is square when it lands: the one moment the shape
/// change is visible is the one moment nothing animates it.
///
/// These shuttles put the clip *inside* the flight and interpolate it, so a
/// tile with 12 px corners opens into a full-screen photo by growing and
/// unrounding at once, and an avatar's circle relaxes into a rectangle on
/// the way to the photo viewer.
///
/// Radii are given as a fraction of the box's shortest side rather than in
/// pixels, because the box is a different size at each end of the flight and
/// a fixed radius would read as a different roundness at each end. `0.5` is
/// a circle (or a stadium), `0` is a square corner.
abstract final class AppHeroFlight {
  /// A shuttle that lerps the corner radius from [fromFactor] at the source
  /// to [toFactor] at the destination.
  ///
  /// Pass it to both [Hero]s of a pair: the framework prefers the
  /// destination's builder on a push and the source's on a pop, so a pair
  /// that only names it on one end flies differently in the two directions.
  static HeroFlightShuttleBuilder corners({
    required double fromFactor,
    required double toFactor,
    Clip clipBehavior = Clip.antiAlias,
  }) {
    return (
      BuildContext flightContext,
      Animation<double> animation,
      HeroFlightDirection direction,
      BuildContext fromHeroContext,
      BuildContext toHeroContext,
    ) {
      // The child that will be left on screen when the flight ends — the
      // same choice the framework's own default shuttle makes.
      final hero =
          (direction == HeroFlightDirection.push
                  ? toHeroContext.widget
                  : fromHeroContext.widget)
              as Hero;

      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          // `animation` always runs 0 → 1 over the flight; on a pop the
          // flight is going the other way, so the factors are read in
          // reverse.
          final t = AppMotion.curve.transform(
            direction == HeroFlightDirection.push
                ? animation.value
                : 1 - animation.value,
          );
          final factor = fromFactor + (toFactor - fromFactor) * t;

          return LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest.shortestSide;
              final radius = side.isFinite ? side * factor : 0.0;

              return ClipRRect(
                clipBehavior: clipBehavior,
                borderRadius: BorderRadius.circular(radius),
                child: hero.child,
              );
            },
          );
        },
      );
    };
  }

  /// A round thing opening into a rectangular one: an avatar into its photo.
  static HeroFlightShuttleBuilder get circleToRect =>
      corners(fromFactor: 0.5, toFactor: 0);

  /// A round thing staying round: an avatar in a list opening into the same
  /// avatar, larger, at the top of a profile. Without this the circle goes
  /// square for the length of the flight.
  static HeroFlightShuttleBuilder get circle =>
      corners(fromFactor: 0.5, toFactor: 0.5);
}
