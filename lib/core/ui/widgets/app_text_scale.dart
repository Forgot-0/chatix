import 'package:flutter/material.dart';

/// Applies the user's own text scale on top of the platform's.
///
/// The OS scale reaches the app through `MediaQuery` already (see
/// `AccessibilityWrapper`); this multiplies the app's preference into it
/// rather than replacing it, so someone who has enlarged type system-wide
/// keeps that enlargement when they also nudge ChatiX's own slider.
class AppTextScale extends StatelessWidget {
  const AppTextScale({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale == 1) return child;

    final data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(
        textScaler: CompoundTextScaler(data.textScaler, scale),
      ),
      child: child,
    );
  }
}

/// A [TextScaler] that multiplies another one by a constant factor.
@immutable
class CompoundTextScaler extends TextScaler {
  const CompoundTextScaler(this.base, this.factor);

  final TextScaler base;

  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize * factor);

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompoundTextScaler &&
          other.base == base &&
          other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
