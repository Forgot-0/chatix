import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';

void main() {
  group('AppThemeMode', () {
    test('maps onto the framework modes', () {
      expect(AppThemeMode.system.material, ThemeMode.system);
      expect(AppThemeMode.light.material, ThemeMode.light);
      expect(AppThemeMode.dark.material, ThemeMode.dark);
    });

    test('an unknown stored value falls back to following the system', () {
      expect(AppThemeMode.fromName('nonsense'), AppThemeMode.system);
      expect(AppThemeMode.fromName(null), AppThemeMode.system);
      expect(AppThemeMode.fromName('dark'), AppThemeMode.dark);
    });
  });

  group('AppDensity', () {
    test('each step gives messages more air than the last', () {
      const order = [
        AppDensity.compact,
        AppDensity.cozy,
        AppDensity.comfortable,
      ];
      for (var i = 1; i < order.length; i++) {
        expect(
          order[i].bubblePaddingY,
          greaterThan(order[i - 1].bubblePaddingY),
        );
        expect(order[i].groupGap, greaterThan(order[i - 1].groupGap));
        expect(
          order[i].listRowPadding,
          greaterThan(order[i - 1].listRowPadding),
        );
      }
    });

    test('a run is always tighter than a gap between authors', () {
      for (final density in AppDensity.values) {
        expect(
          density.stackGap,
          lessThan(density.groupGap),
          reason: density.name,
        );
      }
    });

    test('visual density rises with the setting', () {
      expect(
        AppDensity.compact.visualDensity.vertical,
        lessThan(AppDensity.cozy.visualDensity.vertical),
      );
      expect(
        AppDensity.cozy.visualDensity.vertical,
        lessThan(AppDensity.comfortable.visualDensity.vertical),
      );
    });

    test('names written by the previous build still resolve', () {
      expect(AppDensity.fromName('cosy'), AppDensity.cozy);
      expect(AppDensity.fromName('spacious'), AppDensity.comfortable);
    });

    test('an unknown stored value falls back to the default', () {
      expect(AppDensity.fromName('nonsense'), AppDensity.cozy);
      expect(AppDensity.fromName(null), AppDensity.cozy);
      expect(AppDensity.fromName('compact'), AppDensity.compact);
    });
  });

  group('AppWallpaper', () {
    test('resolves by id and falls back for anything else', () {
      expect(AppWallpaper.fromId('mesh'), AppWallpaper.mesh);
      expect(AppWallpaper.fromId('plain'), AppWallpaper.plain);
      expect(AppWallpaper.fromId('gone'), AppWallpaper.fallback);
      expect(AppWallpaper.fromId(null), AppWallpaper.fallback);
    });

    test('only aurora draws the lattice, only plain drops the blooms', () {
      expect(AppWallpaper.aurora.hasLattice, isTrue);
      expect(AppWallpaper.mesh.hasLattice, isFalse);
      expect(AppWallpaper.plain.hasBlooms, isFalse);
      expect(AppWallpaper.mesh.hasBlooms, isTrue);
    });
  });

  group('AppearanceSettings', () {
    test('defaults to system violet at cozy density', () {
      const settings = AppearanceSettings();
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.density, AppDensity.cozy);
      expect(settings.accentSeed, AppPalette.violet);
      expect(settings.wallpaper, AppWallpaper.aurora);
      expect(settings.textScale, 1);
    });

    test('survives a JSON round trip', () {
      const settings = AppearanceSettings(
        themeMode: AppThemeMode.dark,
        density: AppDensity.compact,
        accentSeed: AppPalette.mint,
        wallpaperId: 'plain',
        textScale: 1.15,
      );

      expect(AppearanceSettings.fromJson(settings.toJson()), settings);
    });

    test('clamps a text scale that would break the layout', () {
      expect(
        const AppearanceSettings().copyWith(textScale: 9).textScale,
        AppearanceSettings.maxTextScale,
      );
      expect(
        const AppearanceSettings().copyWith(textScale: 0).textScale,
        AppearanceSettings.minTextScale,
      );
      expect(
        AppearanceSettings.fromJson(const {'textScale': 42}).textScale,
        AppearanceSettings.maxTextScale,
      );
    });

    test('reads around junk rather than throwing', () {
      final settings = AppearanceSettings.fromJson(const {
        'themeMode': 'neon',
        'density': 'huge',
        'accentSeed': 'not-a-colour',
        'wallpaperId': 'nope',
      });

      expect(settings, const AppearanceSettings());
    });

    test('every offered text-scale step stays inside the allowed range', () {
      for (final step in AppearanceSettings.textScaleSteps) {
        expect(step, greaterThanOrEqualTo(AppearanceSettings.minTextScale));
        expect(step, lessThanOrEqualTo(AppearanceSettings.maxTextScale));
      }
    });

    test('the new appearance fields survive the round trip', () {
      final settings = const AppearanceSettings().copyWith(
        amoled: true,
        wallpaperId: AppWallpaper.halo.id,
        wallpaperIntensity: 0.2,
        wallpaperPattern: 0.9,
        bubbleRadius: 14,
        bubbleAnchored: false,
      );

      expect(AppearanceSettings.fromJson(settings.toJson()), settings);
    });

    test('the wallpaper knobs are held inside 0..1', () {
      expect(
        const AppearanceSettings()
            .copyWith(wallpaperIntensity: 4)
            .wallpaperIntensity,
        1,
      );
      expect(
        const AppearanceSettings()
            .copyWith(wallpaperPattern: -2)
            .wallpaperPattern,
        0,
      );
      expect(
        AppearanceSettings.fromJson(const {
          'wallpaperIntensity': 9,
        }).wallpaperIntensity,
        1,
      );
    });

    test(
      'the bubble radius is held inside the band that still reads as a bubble',
      () {
        expect(
          const AppearanceSettings().copyWith(bubbleRadius: 2).bubbleRadius,
          AppearanceSettings.minBubbleRadius,
        );
        expect(
          const AppearanceSettings().copyWith(bubbleRadius: 99).bubbleRadius,
          AppearanceSettings.maxBubbleRadius,
        );
      },
    );

    test('the anchor corner is tight when on and ordinary when off', () {
      const anchored = AppearanceSettings();
      expect(anchored.bubbleAnchorRadius, AppearanceSettings.anchorRadius);
      expect(anchored.bubbleAnchorRadius, lessThan(anchored.bubbleRadius));

      final flat = anchored.copyWith(bubbleAnchored: false);
      expect(flat.bubbleAnchorRadius, flat.bubbleRadius);
    });

    test('a field of the wrong type reads as its default', () {
      final settings = AppearanceSettings.fromJson(const {
        'amoled': 'yes please',
        'bubbleAnchored': 3,
        'bubbleRadius': 'wide',
        'wallpaperIntensity': 'loud',
        'textScale': 'big',
      });

      expect(settings, const AppearanceSettings());
    });

    test('the gallery holds every style exactly once', () {
      expect(AppWallpaper.gallery.toSet().length, AppWallpaper.values.length);
      expect(AppWallpaper.gallery, contains(AppWallpaper.plain));
      expect(
        AppWallpaper.gallery.map((style) => style.id).toSet().length,
        AppWallpaper.values.length,
      );
    });

    test('copyWith changes one field and equality notices', () {
      const settings = AppearanceSettings();
      final darkened = settings.copyWith(themeMode: AppThemeMode.dark);

      expect(darkened.themeMode, AppThemeMode.dark);
      expect(darkened.density, settings.density);
      expect(darkened, isNot(settings));
      expect(settings.copyWith(), settings);
      expect(settings.hashCode, const AppearanceSettings().hashCode);
    });
  });
}
