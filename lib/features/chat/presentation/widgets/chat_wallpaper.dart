import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/theme_providers.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/theme_config.dart';

/// The ground a conversation is painted on.
///
/// Which pattern it draws comes from appearance settings; [seed] only varies
/// the layout so two chats do not look identical.
class ChatWallpaper extends ConsumerWidget {
  const ChatWallpaper({
    super.key,
    required this.child,
    this.seed = 0,
    this.parallax,
  });

  /// How far the pattern drifts against the messages, in logical pixels.
  ///
  /// A listenable rather than a value so that scrolling moves the pattern
  /// without rebuilding the painter: the mesh is painted once into its own
  /// layer and only the offset of that layer changes.
  ///
  /// Null holds it still, which is also what a reader with reduced motion on
  /// should be given.
  final ValueListenable<double>? parallax;

  /// The amplitude callers are expected to stay inside. The pattern is
  /// painted this much taller than the viewport at both ends, so drifting
  /// never uncovers bare background.
  static const double maxParallax = 16;

  final Widget child;
  final int seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatix = ChatixTheme.of(context);
    final wallpaper = ref.watch(wallpaperProvider);

    final ground = BoxDecoration(color: chatix.chatBackground);

    if (wallpaper == AppWallpaper.plain) {
      return DecoratedBox(decoration: ground, child: child);
    }

    final painter = _MeshPainter(
      accent: chatix.wallpaperSeed,
      secondary: chatix.success,
      isDark: chatix.brightness == Brightness.dark,
      seed: seed,
      showLattice: wallpaper.hasLattice,
    );

    return DecoratedBox(
      decoration: ground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: -maxParallax,
            bottom: -maxParallax,
            child: _DriftingMesh(painter: painter, parallax: parallax),
          ),
          child,
        ],
      ),
    );
  }
}

/// The painted pattern, and the one thing that moves it.
class _DriftingMesh extends StatelessWidget {
  const _DriftingMesh({required this.painter, required this.parallax});

  final CustomPainter painter;
  final ValueListenable<double>? parallax;

  @override
  Widget build(BuildContext context) {
    // Its own layer: the drift then costs a transform on a cached picture
    // rather than a repaint of four radial gradients per frame.
    final mesh = RepaintBoundary(
      child: CustomPaint(
        painter: painter,
        isComplex: true,
        willChange: false,
        child: const SizedBox.expand(),
      ),
    );

    final offset = parallax;
    if (offset == null) return mesh;

    return ValueListenableBuilder<double>(
      valueListenable: offset,
      builder: (context, value, mesh) =>
          Transform.translate(offset: Offset(0, value), child: mesh),
      child: mesh,
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.accent,
    required this.secondary,
    required this.isDark,
    required this.seed,
    required this.showLattice,
  });

  final Color accent;
  final Color secondary;
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
      old.isDark != isDark ||
      old.seed != seed ||
      old.showLattice != showLattice;
}
