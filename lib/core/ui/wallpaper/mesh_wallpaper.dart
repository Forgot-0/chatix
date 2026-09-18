import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/theme_config.dart';

/// Everything the wallpaper painter needs, and nothing it can look up.
///
/// Kept apart from the painter so the recipes can be exercised — and the
/// gallery thumbnails built — without a chat, a theme or a `BuildContext`.
/// Every colour in a finished wallpaper is derived from [accent]: no style
/// carries a hue of its own, which is what makes the whole gallery re-tint
/// the instant the accent changes.
@immutable
class MeshWallpaperSpec {
  const MeshWallpaperSpec({
    required this.style,
    required this.accent,
    required this.brightness,
    this.intensity = AppearanceSettings.defaultWallpaperIntensity,
    this.pattern = AppearanceSettings.defaultWallpaperPattern,
    this.layoutSeed = 0,
    this.highContrast = false,
  });

  final AppWallpaper style;

  /// The one colour the whole pattern is built from.
  final Color accent;

  /// Which ground the pattern is being painted on. Dark grounds take more
  /// colour before the pattern reads at all, so the ramp differs.
  final Brightness brightness;

  /// How loudly the pattern is painted, 0..1.
  final double intensity;

  /// Which arrangement of [style] is drawn, 0..1.
  final double pattern;

  /// Varies the layout between two surfaces sharing a style — one chat's
  /// wallpaper should not be pixel-identical to the next one's.
  final int layoutSeed;

  /// Under the system's high-contrast setting the pattern gives way: text on
  /// a bubble has to win, and a wallpaper is the thing that can afford to
  /// lose. It is dimmed rather than removed, so the setting still looks like
  /// the one that was chosen.
  final bool highContrast;

  bool get isDark => brightness == Brightness.dark;

  /// Alpha the loudest layer is painted at.
  ///
  /// The floor is not zero: a reader who has dragged intensity all the way
  /// down asked for "quiet", and picking `plain` is how they ask for "none".
  double get strength {
    final ceiling = isDark ? 0.34 : 0.24;
    final base = lerpDouble(0.04, ceiling, intensity.clamp(0.0, 1.0))!;
    return highContrast ? base * 0.4 : base;
  }

  /// Alpha for the hairline overlays (lattice, dots), which have to stay far
  /// quieter than the blooms — they are lines, and lines read louder.
  double get lineStrength => strength * (isDark ? 0.14 : 0.12);

  MeshWallpaperSpec copyWith({
    AppWallpaper? style,
    Color? accent,
    Brightness? brightness,
    double? intensity,
    double? pattern,
    int? layoutSeed,
    bool? highContrast,
  }) => MeshWallpaperSpec(
    style: style ?? this.style,
    accent: accent ?? this.accent,
    brightness: brightness ?? this.brightness,
    intensity: intensity ?? this.intensity,
    pattern: pattern ?? this.pattern,
    layoutSeed: layoutSeed ?? this.layoutSeed,
    highContrast: highContrast ?? this.highContrast,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshWallpaperSpec &&
          other.style == style &&
          other.accent == accent &&
          other.brightness == brightness &&
          other.intensity == intensity &&
          other.pattern == pattern &&
          other.layoutSeed == layoutSeed &&
          other.highContrast == highContrast;

  @override
  int get hashCode => Object.hash(
    style,
    accent,
    brightness,
    intensity,
    pattern,
    layoutSeed,
    highContrast,
  );
}

/// The wallpaper recipe the ambient theme carries.
///
/// Everything it needs — style, accent, ground, both knobs — is on
/// [ChatixTheme], and the one thing that is not is the platform's
/// high-contrast switch, which is read straight from `MediaQuery`. So a chat,
/// a settings preview and a gallery thumbnail all get the same recipe from
/// the same place, and none of them needs the settings store to draw.
MeshWallpaperSpec wallpaperSpecOf(BuildContext context, {int layoutSeed = 0}) {
  final chatix = ChatixTheme.of(context);

  return MeshWallpaperSpec(
    style: chatix.wallpaperStyle,
    accent: chatix.wallpaperSeed,
    brightness: chatix.brightness,
    intensity: chatix.wallpaperIntensity,
    pattern: chatix.wallpaperPattern,
    layoutSeed: layoutSeed,
    highContrast: MediaQuery.highContrastOf(context),
  );
}

/// Draws an [MeshWallpaperSpec]. Ground excluded — the caller paints that, so
/// the pattern can sit over a themed surface without knowing its colour.
class MeshWallpaperPainter extends CustomPainter {
  const MeshWallpaperPainter(this.spec);

  final MeshWallpaperSpec spec;

  /// The golden angle. Successive blooms placed this far apart never fall
  /// into rows, at any count — which is what keeps an arrangement reading as
  /// organic rather than as a grid with gaps.
  static const double _goldenAngle = 2.399963229728653;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    switch (spec.style) {
      case AppWallpaper.plain:
        return;
      case AppWallpaper.mesh:
        _paintBlooms(canvas, size, count: 4, spread: 0.42);
      case AppWallpaper.aurora:
        _paintBlooms(canvas, size, count: 4, spread: 0.46);
        _paintLattice(canvas, size);
      case AppWallpaper.nebula:
        _paintBlooms(
          canvas,
          size,
          count: 7 + (spec.pattern * 7).round(),
          spread: 0.5,
          radiusFactor: 0.34,
          hueSpread: 18 + spec.pattern * 44,
        );
      case AppWallpaper.ribbons:
        _paintRibbons(canvas, size);
      case AppWallpaper.prism:
        _paintPrism(canvas, size);
      case AppWallpaper.halo:
        _paintHalo(canvas, size);
      case AppWallpaper.dunes:
        _paintDunes(canvas, size);
    }
  }

  /// Soft radial colour, placed on a golden-angle spiral.
  ///
  /// The spiral is a pure function of the pattern slider rather than a
  /// re-roll of a random seed, so dragging it moves the blooms along a path
  /// instead of teleporting them somewhere new on every frame.
  void _paintBlooms(
    Canvas canvas,
    Size size, {
    required int count,
    required double spread,
    double radiusFactor = 0.5,
    double hueSpread = 0,
  }) {
    final phase = spec.pattern * math.pi * 2 + spec.layoutSeed * 0.618;
    final accent = HSLColor.fromColor(spec.accent);

    for (var i = 0; i < count; i++) {
      final angle = i * _goldenAngle + phase;
      final distance = math.sqrt((i + 0.6) / count);

      final center = Offset(
        size.width * (0.5 + spread * distance * math.cos(angle)),
        size.height * (0.5 + (spread + 0.06) * distance * math.sin(angle)),
      );

      final radius =
          size.shortestSide *
          (radiusFactor + 0.3 * (1 - distance)) *
          (0.85 + 0.3 * spec.pattern);

      // Every other bloom is pulled towards the secondary hue, so the mesh
      // has somewhere to travel between rather than being one colour twice.
      final shift = hueSpread == 0
          ? (i.isEven ? 0.0 : 34.0)
          : hueSpread * (i / math.max(count - 1, 1) - 0.5) * 2;
      final color = _shiftHue(accent, shift);

      final alpha = spec.strength * (1 - 0.14 * i).clamp(0.4, 1.0);

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  /// The faint diagonal hairlines that make `aurora` more than blooms.
  void _paintLattice(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (spec.isDark ? Colors.white : Colors.black).withValues(
        alpha: spec.isDark ? 0.025 : 0.02,
      )
      ..strokeWidth = 1;

    final step = lerpDouble(64, 30, spec.pattern)!;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  /// Wide horizontal bands with a slow sine to them.
  void _paintRibbons(Canvas canvas, Size size) {
    final accent = HSLColor.fromColor(spec.accent);
    final bands = 3 + (spec.pattern * 4).round();
    final amplitude = size.height * (0.03 + 0.1 * spec.pattern);
    final thickness = size.height / bands * 0.62;

    for (var i = 0; i < bands; i++) {
      final y = size.height * (i + 0.5) / bands;
      final color = _shiftHue(accent, i.isEven ? 0 : 30);

      final path = Path()..moveTo(-thickness, y);
      const steps = 24;
      for (var s = 0; s <= steps; s++) {
        final t = s / steps;
        final wave = math.sin(
          t * math.pi * 2 + i * 0.9 + spec.layoutSeed * 0.3,
        );
        path.lineTo(size.width * t, y + wave * amplitude);
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 0.5)
          ..color = color.withValues(alpha: spec.strength * 0.8),
      );
    }
  }

  /// Angular facets struck from one corner — the only style with a hard edge
  /// in it, which is what keeps the gallery from being eight soft blurs.
  void _paintPrism(Canvas canvas, Size size) {
    final accent = HSLColor.fromColor(spec.accent);
    final origin = Offset(
      size.width * (spec.layoutSeed.isEven ? 0 : 1),
      -size.height * 0.1,
    );
    final wedges = 4 + (spec.pattern * 7).round();
    final reach = size.longestSide * 2;
    final sweep = math.pi / 2 / wedges;
    final start = spec.layoutSeed.isEven
        ? math.pi / 2 - spec.pattern * 0.4
        : math.pi - spec.pattern * 0.4;

    for (var i = 0; i < wedges; i++) {
      final a0 = start + i * sweep;
      final a1 = a0 + sweep;
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(
          origin.dx + reach * math.cos(a0),
          origin.dy + reach * math.sin(a0),
        )
        ..lineTo(
          origin.dx + reach * math.cos(a1),
          origin.dy + reach * math.sin(a1),
        )
        ..close();

      final color = _shiftHue(accent, (i - wedges / 2) * 9);
      final alpha = spec.strength * (i.isEven ? 0.85 : 0.45);

      canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
    }
  }

  /// Concentric rings around a centre parked off the canvas.
  void _paintHalo(Canvas canvas, Size size) {
    final accent = HSLColor.fromColor(spec.accent);
    final center = Offset(
      size.width * (spec.layoutSeed.isEven ? 0.82 : 0.18),
      size.height * (0.12 + 0.2 * spec.pattern),
    );

    final rings = 4 + (spec.pattern * 8).round();
    final gap = size.longestSide / rings * 0.9;
    final stroke = gap * 0.42;

    for (var i = rings; i > 0; i--) {
      final color = _shiftHue(accent, i.isEven ? 0 : 26);
      canvas.drawCircle(
        center,
        gap * i,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.55)
          ..color = color.withValues(
            alpha: spec.strength * (0.3 + 0.7 * (1 - i / rings)),
          ),
      );
    }
  }

  /// Stacked arcs rising out of the bottom edge.
  void _paintDunes(Canvas canvas, Size size) {
    final accent = HSLColor.fromColor(spec.accent);
    final layers = 3 + (spec.pattern * 3).round();

    for (var i = layers; i > 0; i--) {
      final t = i / layers;
      final crest = size.height * (1 - t * (0.45 + 0.35 * spec.pattern));
      final lift = size.height * (0.06 + 0.1 * spec.pattern) * t;

      final path = Path()
        ..moveTo(0, size.height)
        ..lineTo(0, crest + lift)
        ..cubicTo(
          size.width * 0.3,
          crest - lift,
          size.width * 0.7,
          crest + lift * 2,
          size.width,
          crest - lift * 0.5,
        )
        ..lineTo(size.width, size.height)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = _shiftHue(
            accent,
            i.isEven ? 0 : 28,
          ).withValues(alpha: spec.strength * (0.28 + 0.72 * (1 - t))),
      );
    }
  }

  /// Rotates a hue while keeping the accent's own saturation and lightness,
  /// so a second colour still reads as a relative of the first.
  static Color _shiftHue(HSLColor base, double degrees) {
    if (degrees == 0) return base.toColor();
    return base.withHue((base.hue + degrees) % 360).toColor();
  }

  @override
  bool shouldRepaint(MeshWallpaperPainter old) => old.spec != spec;
}

/// A painted wallpaper, ground included.
///
/// The one widget both the chat and the settings preview draw with, so what
/// the gallery shows is what a conversation gets — not a picture of it.
class MeshWallpaperView extends StatelessWidget {
  const MeshWallpaperView({
    super.key,
    required this.spec,
    required this.ground,
    this.child,
  });

  final MeshWallpaperSpec spec;

  /// The surface under the pattern.
  final Color ground;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final body = child ?? const SizedBox.expand();

    if (spec.style == AppWallpaper.plain) {
      return DecoratedBox(
        decoration: BoxDecoration(color: ground),
        child: body,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: ground),
      child: CustomPaint(
        painter: MeshWallpaperPainter(spec),
        isComplex: true,
        willChange: false,
        child: body,
      ),
    );
  }
}
