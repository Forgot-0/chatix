import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/theme/theme_generator.dart';

void main() {
  group('ThemeGenerator', () {
    test('carries the ChatiX extension in both brightnesses', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        expect(theme.extension<ChatixTheme>(), isNotNull);
      }
    });

    test('is violet, not the Material default blue', () {
      expect(AppTheme.lightTheme.colorScheme.primary, AppPalette.violet);
      expect(AppTheme.lightTheme.colorScheme.secondary, AppPalette.mint);
      expect(AppTheme.lightTheme.colorScheme.error, AppPalette.coral);
    });

    test('follows a chosen accent instead of the default', () {
      final azure = AppPalette.accentSeeds.last;
      final theme = AppTheme.light(
        const AppearanceSettings().copyWith(accentSeed: azure),
      );

      expect(theme.colorScheme.primary, azure);
      expect(
        theme.extension<ChatixTheme>()!.wallpaperSeed,
        theme.colorScheme.primary,
      );
    });

    test('lifts a dark accent so it stays legible on a dark ground', () {
      final scheme = ThemeGenerator.schemeFor(
        AppPalette.violet,
        Brightness.dark,
      );

      expect(
        HSLColor.fromColor(scheme.primary).lightness,
        greaterThan(HSLColor.fromColor(AppPalette.violet).lightness),
      );
      // Readable against the dark ground it sits on.
      expect(
        AppContrast.ratio(scheme.primary, scheme.surface),
        greaterThan(4.5),
      );
    });

    test('every accent gets a foreground that meets AA on its own fill', () {
      for (final seed in AppPalette.accentSeeds) {
        for (final brightness in Brightness.values) {
          final scheme = ThemeGenerator.schemeFor(seed, brightness);
          expect(
            AppContrast.ratio(scheme.primary, scheme.onPrimary),
            greaterThan(4.5),
            reason: '$seed on ${brightness.name}',
          );
        }
      }
    });

    test('paints its surfaces from the warm ramp, not Material greys', () {
      expect(
        AppTheme.lightTheme.colorScheme.surface,
        AppNeutrals.canvas(Brightness.light),
      );
      expect(
        AppTheme.darkTheme.colorScheme.surface,
        AppNeutrals.canvas(Brightness.dark),
      );
      expect(
        AppTheme.darkTheme.scaffoldBackgroundColor,
        AppTheme.darkTheme.colorScheme.surface,
      );
    });

    test('surface containers ascend without repeating a step', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final scheme = theme.colorScheme;
        final containers = {
          scheme.surfaceContainerLowest,
          scheme.surfaceContainerLow,
          scheme.surfaceContainer,
          scheme.surfaceContainerHigh,
          scheme.surfaceContainerHighest,
        };
        expect(containers, hasLength(5), reason: theme.brightness.name);
      }
    });

    test('uses the bundled grotesque', () {
      expect(AppTheme.lightTheme.textTheme.bodyMedium?.fontFamily, 'Manrope');
    });

    test('numeric styles ask for tabular figures so digits do not jump', () {
      final text = AppTheme.lightTheme.textTheme;
      for (final style in [text.labelSmall, text.labelMedium, text.labelLarge]) {
        expect(
          style?.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });

    test('density reaches the theme extension and the framework', () {
      final comfortable = AppTheme.light(
        const AppearanceSettings(density: AppDensity.comfortable),
      );
      final compact = AppTheme.light(
        const AppearanceSettings(density: AppDensity.compact),
      );

      expect(
        comfortable.extension<ChatixTheme>()!.density,
        AppDensity.comfortable,
      );
      expect(comfortable.visualDensity, AppDensity.comfortable.visualDensity);
      expect(
        comfortable.listTileTheme.minVerticalPadding,
        greaterThan(compact.listTileTheme.minVerticalPadding!),
      );
    });

    test('the same settings build an equal theme twice', () {
      const settings = AppearanceSettings(density: AppDensity.compact);
      expect(
        AppTheme.light(settings).colorScheme,
        AppTheme.light(settings).colorScheme,
      );
    });

    test('animates with the system curve and duration', () {
      final builder = AppTheme
          .lightTheme
          .pageTransitionsTheme
          .builders[TargetPlatform.android];

      expect(builder, isNotNull);
      expect(builder!.transitionDuration, AppMotion.base);
    });
  });
}
