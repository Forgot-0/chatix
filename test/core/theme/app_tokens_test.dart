import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_tokens.dart';

void main() {
  group('AppNeutrals', () {
    test('both ramps carry the documented number of steps', () {
      expect(AppNeutrals.light, hasLength(AppNeutrals.steps));
      expect(AppNeutrals.dark, hasLength(AppNeutrals.steps));
    });

    test('each ramp darkens monotonically', () {
      for (final ramp in [AppNeutrals.light, AppNeutrals.dark]) {
        for (var i = 1; i < ramp.length; i++) {
          expect(
            HSLColor.fromColor(ramp[i]).lightness,
            lessThan(HSLColor.fromColor(ramp[i - 1]).lightness),
            reason: 'step $i is not darker than step ${i - 1}',
          );
        }
      }
    });

    test('the ramp is warm, never a neutral grey', () {
      for (final ramp in [AppNeutrals.light, AppNeutrals.dark]) {
        for (final color in ramp) {
          // Warmth means more red than blue; a pure grey would be equal.
          expect(
            (color.r * 255).round(),
            greaterThan((color.b * 255).round()),
            reason: '$color has no warmth',
          );
        }
      }
    });

    test('roles land on opposite ends for the two brightnesses', () {
      expect(
        HSLColor.fromColor(AppNeutrals.canvas(Brightness.light)).lightness,
        greaterThan(
          HSLColor.fromColor(AppNeutrals.canvas(Brightness.dark)).lightness,
        ),
      );
      expect(
        HSLColor.fromColor(AppNeutrals.text(Brightness.light)).lightness,
        lessThan(
          HSLColor.fromColor(AppNeutrals.text(Brightness.dark)).lightness,
        ),
      );
    });

    test('an out-of-range step clamps instead of throwing', () {
      expect(AppNeutrals.step(Brightness.light, -3), AppNeutrals.light.first);
      expect(AppNeutrals.step(Brightness.light, 99), AppNeutrals.light.last);
    });
  });

  group('AppElevations', () {
    test('light casts a shadow that grows with the level', () {
      var previousBlur = 0.0;
      for (var level = 1; level <= AppElevations.levels; level++) {
        final shadows = AppElevations.shadows(Brightness.light, level);
        expect(shadows, hasLength(1));
        expect(shadows.single.blurRadius, greaterThan(previousBlur));
        previousBlur = shadows.single.blurRadius;
      }
    });

    test('dark never casts one — a black shadow on near-black is invisible', () {
      for (var level = 0; level <= AppElevations.levels; level++) {
        expect(AppElevations.shadows(Brightness.dark, level), isEmpty);
      }
    });

    test('dark expresses lift by moving the surface towards white', () {
      final base = AppNeutrals.dark[9];
      var previous = HSLColor.fromColor(base).lightness;

      for (var level = 1; level <= AppElevations.levels; level++) {
        final lifted = AppElevations.surfaceOf(Brightness.dark, base, level);
        final lightness = HSLColor.fromColor(lifted).lightness;
        expect(lightness, greaterThan(previous), reason: 'level $level');
        previous = lightness;
      }
    });

    test('light surfaces are left alone — the shadow does the work', () {
      const base = Color(0xFFFFFFFF);
      for (var level = 1; level <= AppElevations.levels; level++) {
        expect(AppElevations.surfaceOf(Brightness.light, base, level), base);
      }
    });

    test('level 0 is flat in both brightnesses', () {
      const base = Color(0xFF241F1A);
      expect(AppElevations.surfaceOf(Brightness.dark, base, 0), base);
      expect(AppElevations.shadows(Brightness.light, 0), isEmpty);
    });

    test('a level past the scale clamps to the top one', () {
      expect(
        AppElevations.shadows(Brightness.light, 99),
        AppElevations.shadows(Brightness.light, AppElevations.levels),
      );
    });
  });

  group('scales', () {
    test('radii ascend', () {
      for (var i = 1; i < AppRadii.scale.length; i++) {
        expect(AppRadii.scale[i], greaterThan(AppRadii.scale[i - 1]));
      }
    });

    test('spacing is the 4pt grid, 4 through 32', () {
      expect(AppSpacing.scale.first, 4);
      expect(AppSpacing.scale.last, 32);
      for (final space in AppSpacing.scale) {
        expect(space % 4, 0, reason: '$space is off the grid');
      }
    });

    test('durations ascend from fast to slow', () {
      expect(AppMotion.fast, const Duration(milliseconds: 120));
      expect(AppMotion.base, const Duration(milliseconds: 220));
      expect(AppMotion.slow, const Duration(milliseconds: 320));
      expect(AppMotion.curve, Curves.easeOutCubic);
    });
  });

  group('AppAuthorPalette', () {
    test('both ramps hold the documented eight accents', () {
      expect(AppAuthorPalette.light, hasLength(AppAuthorPalette.size));
      expect(AppAuthorPalette.dark, hasLength(AppAuthorPalette.size));
    });

    test('the two ramps differ, so an accent stays readable on either ground', () {
      for (var i = 0; i < AppAuthorPalette.size; i++) {
        expect(AppAuthorPalette.light[i], isNot(AppAuthorPalette.dark[i]));
      }
    });

    test('accents inside a ramp are distinct', () {
      expect(AppAuthorPalette.light.toSet(), hasLength(AppAuthorPalette.size));
      expect(AppAuthorPalette.dark.toSet(), hasLength(AppAuthorPalette.size));
    });
  });
}
