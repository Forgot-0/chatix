import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';

void main() {
  final light = ChatixTheme.light();
  final dark = ChatixTheme.dark();

  group('author accents', () {
    test('are stable for the same user id', () {
      expect(light.authorColor(42), light.authorColor(42));
    });

    test('differ between themes so they stay readable on either ground', () {
      expect(light.authorColor(42), isNot(dark.authorColor(42)));
    });

    test('spread ids across the whole palette', () {
      final used = {
        for (var id = 0; id < light.authorPalette.length; id++)
          light.authorColor(id),
      };
      expect(used, hasLength(light.authorPalette.length));
    });

    test('wrap instead of overflowing on a large id', () {
      expect(
        light.authorColor(light.authorPalette.length + 3),
        light.authorColor(3),
      );
    });

    test('handle a negative id rather than throwing', () {
      expect(() => light.authorColor(-5), returnsNormally);
    });

    test('fall back to a neutral for an unknown author', () {
      expect(light.authorColor(null), AppNeutrals.outline(Brightness.light));
      expect(dark.authorColor(null), AppNeutrals.outline(Brightness.dark));
    });

    test('the palette is the documented eight', () {
      expect(light.authorPalette, hasLength(AppAuthorPalette.size));
    });
  });

  group('derivation from the colour scheme', () {
    test('follows the accent rather than hard-coding violet', () {
      final crimson = ChatixTheme.fromScheme(
        scheme: ColorScheme.fromSeed(seedColor: AppPalette.coral),
        density: AppDensity.cozy,
      );

      expect(crimson.bubbleOutgoingGradient.colors.first, isNot(
        light.bubbleOutgoingGradient.colors.first,
      ));
      expect(crimson.wallpaperSeed, isNot(light.wallpaperSeed));
      expect(crimson.unreadDivider, isNot(light.unreadDivider));
    });

    test('the outgoing gradient runs light to dark', () {
      for (final theme in [light, dark]) {
        final colors = theme.bubbleOutgoingGradient.colors;
        expect(colors, hasLength(2));
        expect(
          HSLColor.fromColor(colors.last).lightness,
          lessThan(HSLColor.fromColor(colors.first).lightness),
        );
      }
    });

    test('bubble text contrasts with the bubble it sits on', () {
      expect(
        ThemeData.estimateBrightnessForColor(
          light.bubbleOutgoingGradient.colors.first,
        ),
        isNot(ThemeData.estimateBrightnessForColor(
          light.bubbleOutgoingForeground,
        )),
      );

      for (final theme in [light, dark]) {
        expect(
          ThemeData.estimateBrightnessForColor(theme.bubbleIncoming),
          isNot(
            ThemeData.estimateBrightnessForColor(
              theme.bubbleIncomingForeground,
            ),
          ),
          reason: theme.brightness.name,
        );
      }
    });

    test('an incoming bubble is separated by a hairline in light and by lift in dark', () {
      expect(light.bubbleIncomingBorder.a, greaterThan(0));
      expect(dark.bubbleIncomingBorder, Colors.transparent);
      expect(
        HSLColor.fromColor(dark.bubbleIncoming).lightness,
        greaterThan(HSLColor.fromColor(dark.chatBackground).lightness),
      );
    });

    test('a selected reaction chip reads differently from an idle one', () {
      for (final theme in [light, dark]) {
        expect(
          theme.reactionChipSelected,
          isNot(theme.reactionChip),
          reason: theme.brightness.name,
        );
      }
    });

    test('the composer separates from the conversation ground', () {
      for (final theme in [light, dark]) {
        expect(
          theme.composerSurface,
          isNot(theme.chatBackground),
          reason: theme.brightness.name,
        );
      }
    });

    test('outgoing text meets AA on every offered accent', () {
      for (final seed in AppPalette.accentSeeds) {
        for (final brightness in Brightness.values) {
          final theme = ChatixTheme.fromScheme(
            scheme: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: brightness,
            ),
            density: AppDensity.cozy,
            accent: seed,
          );

          expect(
            AppContrast.ratio(
              theme.bubbleOutgoingGradient.colors.first,
              theme.bubbleOutgoingForeground,
            ),
            greaterThan(4.5),
            reason: '$seed on ${brightness.name}',
          );
        }
      }
    });

    test('density reaches the extension', () {
      expect(ChatixTheme.light(AppDensity.comfortable).density,
          AppDensity.comfortable);
    });
  });

  group('theme extension plumbing', () {
    test('lerp lands on each end and never throws in between', () {
      final start = light.lerp(dark, 0);
      expect(start.bubbleIncoming, light.bubbleIncoming);
      expect(start.brightness, light.brightness);

      final end = light.lerp(dark, 1);
      expect(end.bubbleIncoming, dark.bubbleIncoming);
      expect(end.brightness, dark.brightness);
      expect(end.authorPalette, dark.authorPalette);

      final middle = light.lerp(dark, 0.5);
      expect(middle.authorPalette, hasLength(AppAuthorPalette.size));
      expect(middle.bubbleRadius, light.bubbleRadius);
      expect(middle.chatBackground, isNot(light.chatBackground));
    });

    test('lerp against another extension keeps this one', () {
      expect(light.lerp(null, 0.5), light);
    });

    test('copyWith replaces only what it is given', () {
      final swapped = light.copyWith(onlineDot: AppPalette.amber);
      expect(swapped.onlineDot, AppPalette.amber);
      expect(swapped.bubbleIncoming, light.bubbleIncoming);
    });

    testWidgets('of() falls back outside a ChatiX theme', (tester) async {
      late ChatixTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = ChatixTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved.authorPalette, hasLength(AppAuthorPalette.size));
    });
  });
}
