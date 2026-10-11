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
  /// "Source" and "destination" are the push's: on the way back the same
  /// pair flies the other way, from [toFactor] to [fromFactor], so a photo
  /// that unrounded as it opened rounds again as it lands.
  ///
  /// With [crossFade], the source's picture stays under the destination's
  /// and the destination's fades in over the flight. A destination still
  /// decoding its full-size frame — a photo opened into a viewer — would
  /// otherwise fly as its loading placeholder and only then turn into the
  /// picture it left from; with the source underneath, the picture is there
  /// for the whole flight. Both children are drawn into the same box, so it
  /// only suits a pair that fills it the same way ([BoxFit.cover] at both
  /// ends).
  ///
  /// Pass it to both [Hero]s of a pair: the framework prefers the
  /// destination's builder on a push and the source's on a pop, so a pair
  /// that only names it on one end flies differently in the two directions.
  static HeroFlightShuttleBuilder corners({
    required double fromFactor,
    required double toFactor,
    Clip clipBehavior = Clip.antiAlias,
    bool crossFade = false,
  }) {
    return (
      BuildContext flightContext,
      Animation<double> animation,
      HeroFlightDirection direction,
      BuildContext fromHeroContext,
      BuildContext toHeroContext,
    ) {
      final isPush = direction == HeroFlightDirection.push;

      // The push's two ends, whichever way this flight is going: on a pop
      // the framework calls the destination "from".
      final source =
          (isPush ? fromHeroContext.widget : toHeroContext.widget) as Hero;
      final destination =
          (isPush ? toHeroContext.widget : fromHeroContext.widget) as Hero;

      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          // `animation` is the pushed route's own: 0 with the route away and
          // 1 with it in place. It runs forward on a push and backward on a
          // pop, so the same value means the same point on the way in either
          // direction — reading it in reverse on a pop would hand a
          // full-screen picture the source's corners the moment it starts
          // back, and land it square.
          final t = AppMotion.curve.transform(animation.value);
          final factor = fromFactor + (toFactor - fromFactor) * t;

          final child = crossFade
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    source.child,
                    Opacity(opacity: t, child: destination.child),
                  ],
                )
              : destination.child;

          return LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest.shortestSide;
              final radius = side.isFinite ? side * factor : 0.0;

              return ClipRRect(
                clipBehavior: clipBehavior,
                borderRadius: BorderRadius.circular(radius),
                child: child,
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
