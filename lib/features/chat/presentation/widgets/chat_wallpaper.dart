import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';

class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({
    super.key,
    required this.child,
    this.seed = 0,
    this.showLattice = true,
  });

  final Widget child;
  final int seed;
  final bool showLattice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(color: theme.colorScheme.surface),
      child: CustomPaint(
        painter: _MeshPainter(
          accent: chatix.wallpaperSeed,
          secondary: chatix.success,
          surface: theme.colorScheme.surface,
          isDark: theme.brightness == Brightness.dark,
          seed: seed,
          showLattice: showLattice,
        ),
        isComplex: true,
        willChange: false,
        child: child,
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.accent,
    required this.secondary,
    required this.surface,
    required this.isDark,
    required this.seed,
    required this.showLattice,
  });

  final Color accent;
  final Color secondary;
  final Color surface;
  final bool isDark;
  final int seed;
  final bool showLattice;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);

    final strength = isDark ? 0.22 : 0.14;

    final blooms = [
      (color: accent, alpha: strength),
      (color: secondary, alpha: strength * 0.75),
      (color: accent, alpha: strength * 0.6),
      (color: secondary, alpha: strength * 0.5),
    ];

    for (final bloom in blooms) {
      final center = Offset(
        size.width * (0.1 + rng.nextDouble() * 0.8),
        size.height * (0.05 + rng.nextDouble() * 0.9),
      );
      final radius = size.shortestSide * (0.45 + rng.nextDouble() * 0.5);

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              bloom.color.withValues(alpha: bloom.alpha),
              bloom.color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    if (!showLattice) return;

    final lattice = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(
        alpha: isDark ? 0.025 : 0.02,
      )
      ..strokeWidth = 1;

    const step = 44.0;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        lattice,
      );
    }
  }

  @override
  bool shouldRepaint(_MeshPainter old) =>
      old.accent != accent ||
      old.secondary != secondary ||
      old.surface != surface ||
      old.isDark != isDark ||
      old.seed != seed ||
      old.showLattice != showLattice;
}
