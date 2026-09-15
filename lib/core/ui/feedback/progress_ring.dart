import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A circle drawn as an arc around whatever it is given, starting at twelve
/// o'clock and running clockwise.
///
/// Not [CircularProgressIndicator]: that one is sized to be an indicator in
/// its own right, and this is a border — it takes the size of its child and
/// draws on its perimeter, which is what a countdown around a round button
/// or a round video is.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.trackColor,
    this.stroke = 3,
    this.child,
  });

  /// How much of the circle is filled, `[0, 1]`. Values outside are clamped
  /// rather than refused: a clock that overshoots its last tick should draw
  /// a full ring, not throw.
  final double progress;

  final Color color;

  /// The unfilled remainder. Null leaves it undrawn, which is what a ring
  /// over a photograph wants.
  final Color? trackColor;

  final double stroke;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _RingPainter(
        progress: progress.clamp(0.0, 1.0),
        color: color,
        trackColor: trackColor,
        stroke: stroke,
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color? trackColor;
  final double stroke;

  static const double _turn = 2 * math.pi;

  /// Twelve o'clock. Canvas angles start at three.
  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    // The stroke straddles the path, so the path sits half a stroke inside
    // the box or the ring is clipped by its own bounds.
    final bounds = (Offset.zero & size).deflate(stroke / 2);
    if (bounds.width <= 0 || bounds.height <= 0) return;

    final track = trackColor;
    if (track != null) {
      canvas.drawArc(bounds, 0, _turn, false, _paint(track));
    }

    if (progress <= 0) return;
    canvas.drawArc(
      bounds,
      _start,
      _turn * progress,
      false,
      _paint(color)..strokeCap = StrokeCap.round,
    );
  }

  Paint _paint(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke;

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.stroke != stroke;
}
