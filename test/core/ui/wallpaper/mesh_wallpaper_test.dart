import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/ui/wallpaper/mesh_wallpaper.dart';

/// The wallpapers are code, not pictures. What has to hold is that the knobs
/// mean what they say, that every recipe in the gallery can actually be
/// drawn, and that the painter does not repaint when nothing has changed —
/// it sits behind a whole conversation.
void main() {
  const base = MeshWallpaperSpec(
    style: AppWallpaper.aurora,
    accent: AppPalette.violet,
    brightness: Brightness.light,
  );

  /// Runs a painter over a canvas, which is where a bad path or a negative
  /// radius would throw.
  void paint(MeshWallpaperSpec spec, [Size size = const Size(320, 640)]) {
    final recorder = ui.PictureRecorder();
    MeshWallpaperPainter(spec).paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
  }

  group('the intensity knob', () {
    test('turns the pattern up', () {
      final quiet = base.copyWith(intensity: 0).strength;
      final middling = base.copyWith(intensity: 0.5).strength;
      final loud = base.copyWith(intensity: 1).strength;

      expect(middling, greaterThan(quiet));
      expect(loud, greaterThan(middling));
    });

    test('never reaches zero — that is what "plain" is for', () {
      expect(base.copyWith(intensity: 0).strength, greaterThan(0));
    });

    test('a dark ground takes more colour before it reads', () {
      expect(
        base.copyWith(brightness: Brightness.dark).strength,
        greaterThan(base.strength),
      );
    });
  });

  test('high contrast dims the pattern rather than removing it', () {
    final dimmed = base.copyWith(highContrast: true).strength;

    expect(dimmed, lessThan(base.strength));
    expect(dimmed, greaterThan(0));
  });

  test('every style in the gallery paints', () {
    for (final style in AppWallpaper.gallery) {
      for (final pattern in <double>[0, 0.5, 1]) {
        expect(
          () => paint(base.copyWith(style: style, pattern: pattern)),
          returnsNormally,
          reason: '${style.id} at pattern $pattern',
        );
      }
    }
  });

  test('a canvas with no area is left alone rather than divided by', () {
    expect(() => paint(base, Size.zero), returnsNormally);
    expect(() => paint(base, const Size(0, 400)), returnsNormally);
  });

  group('repainting', () {
    test('is skipped when the recipe is identical', () {
      expect(
        MeshWallpaperPainter(base).shouldRepaint(MeshWallpaperPainter(base)),
        isFalse,
      );
    });

    test('happens for every knob that changes what is drawn', () {
      final variants = <MeshWallpaperSpec>[
        base.copyWith(style: AppWallpaper.halo),
        base.copyWith(accent: AppPalette.mint),
        base.copyWith(brightness: Brightness.dark),
        base.copyWith(intensity: 0.9),
        base.copyWith(pattern: 0.9),
        base.copyWith(layoutSeed: 3),
        base.copyWith(highContrast: true),
      ];

      for (final variant in variants) {
        expect(
          MeshWallpaperPainter(
            base,
          ).shouldRepaint(MeshWallpaperPainter(variant)),
          isTrue,
        );
      }
    });
  });

  group('the view', () {
    testWidgets('paints nothing over the ground when the style is plain', (
      tester,
    ) async {
      await tester.pumpWidget(
        MeshWallpaperView(
          spec: base.copyWith(style: AppWallpaper.plain),
          ground: const Color(0xFF123456),
        ),
      );

      expect(find.byType(CustomPaint), findsNothing);
    });

    testWidgets('takes its recipe off the theme', (tester) async {
      final settings = const AppearanceSettings().copyWith(
        wallpaperId: AppWallpaper.dunes.id,
        wallpaperIntensity: 0.8,
        wallpaperPattern: 0.2,
        accentSeed: AppPalette.rose,
      );

      late MeshWallpaperSpec resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(settings),
          home: Builder(
            builder: (context) {
              resolved = wallpaperSpecOf(context, layoutSeed: 4);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved.style, AppWallpaper.dunes);
      expect(resolved.intensity, 0.8);
      expect(resolved.pattern, 0.2);
      expect(resolved.accent, AppPalette.rose);
      expect(resolved.layoutSeed, 4);
      expect(resolved.highContrast, isFalse);
    });

    testWidgets('carries the platform high-contrast switch through', (
      tester,
    ) async {
      late MeshWallpaperSpec resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) {
                resolved = wallpaperSpecOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(resolved.highContrast, isTrue);
    });
  });
}
