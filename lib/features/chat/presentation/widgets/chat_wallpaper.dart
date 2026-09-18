import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/ui/wallpaper/mesh_wallpaper.dart';

/// The ground a conversation is painted on.
///
/// Style, intensity, pattern and colour all come off the theme, which the
/// generator builds from appearance settings — so the wallpaper the settings
/// gallery shows and the one a chat gets are the same recipe run twice.
/// [seed] only varies the layout, so two chats do not look identical.
class ChatWallpaper extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final chatix = ChatixTheme.of(context);
    final ground = BoxDecoration(color: chatix.chatBackground);

    if (chatix.wallpaperStyle == AppWallpaper.plain) {
      return DecoratedBox(decoration: ground, child: child);
    }

    final spec = wallpaperSpecOf(context, layoutSeed: seed);

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
            child: _DriftingMesh(
              painter: MeshWallpaperPainter(spec),
              parallax: parallax,
            ),
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
