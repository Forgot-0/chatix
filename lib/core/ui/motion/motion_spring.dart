import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// A value a finger drags and a spring returns.
///
/// The thing that makes a drag feel attached to the finger rather than
/// animated at it is that letting go hands the *velocity* to the return: a
/// flick springs back fast, a slow release settles slowly, and neither of
/// them is a fixed 220 ms tween. That is three lines of physics every
/// gesture in the app would otherwise repeat slightly differently, so it
/// lives here.
///
/// Owns an unbounded [AnimationController]; the caller owns the ticker:
///
/// ```dart
/// late final _drag = GestureSpring(vsync: this);
///
/// @override
/// void dispose() {
///   _drag.dispose();
///   super.dispose();
/// }
/// ```
///
/// Under reduced motion the spring is not slowed down, it is skipped — see
/// [settle]. A rubber band that snaps instead of springing is still a rubber
/// band; a slower one is still motion nobody asked for.
class GestureSpring {
  GestureSpring({
    required TickerProvider vsync,
    this.spring = AppMotion.gestureSpring,
    double initialValue = 0,
  }) : _controller = AnimationController.unbounded(
         vsync: vsync,
         value: initialValue,
       );

  final AnimationController _controller;

  final SpringDescription spring;

  /// The fastest release the spring is asked to honour.
  ///
  /// A flick can report thousands of pixels a second; past this the extra
  /// speed only buys overshoot nobody asked for.
  static const double maxVelocity = 4000;

  /// Repaint on this, and read [value] inside the builder.
  Listenable get animation => _controller;

  double get value => _controller.value;

  /// Follows the finger. No animation: this *is* the finger.
  set value(double next) {
    _controller.stop();
    _controller.value = next;
  }

  /// Adds one drag delta, after passing it through [resist].
  void drag(double delta, {double? threshold, double? limit}) {
    final raw = _controller.value + delta;
    value = threshold == null || limit == null
        ? raw
        : resist(raw, threshold: threshold, limit: limit);
  }

  /// Springs back to [target], carrying [velocity] (pixels per second) into
  /// the return.
  ///
  /// Returns a future that completes when the spring has stopped, so a
  /// caller can wait for the gesture to be visually over.
  TickerFuture settle({
    double target = 0,
    double velocity = 0,
    bool reducedMotion = false,
  }) {
    if (_controller.value == target) {
      _controller.stop();
      return TickerFuture.complete();
    }

    if (reducedMotion) {
      _controller.stop();
      _controller.value = target;
      return TickerFuture.complete();
    }

    return _controller.animateWith(
      SpringSimulation(
        spring,
        _controller.value,
        target,
        velocity.clamp(-maxVelocity, maxVelocity),
      ),
    );
  }

  void dispose() => _controller.dispose();

  /// Rubber-banding: past [threshold] the value keeps moving, but with
  /// diminishing returns, approaching [limit] without ever reaching it.
  ///
  /// A hard stop at the threshold tells the finger it has hit a wall, which
  /// is a lie — the gesture is still live and can still be cancelled. This
  /// says "there is nothing more this way" without taking the drag away.
  ///
  /// Static, and a pure function of its inputs, so a gesture that does its
  /// own bookkeeping can still borrow the curve.
  static double resist(
    double raw, {
    required double threshold,
    required double limit,
  }) {
    if (raw <= 0) return 0;
    if (raw <= threshold) return raw;

    final room = limit - threshold;
    if (room <= 0) return threshold;

    final over = raw - threshold;
    return threshold + room * (1 - 1 / (1 + over / room));
  }
}
