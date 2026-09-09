import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/chatix_palette.dart';

void main() {
  group('authorColor', () {
    test('is stable for the same user id', () {
      expect(
        ChatixPalette.authorColor(42, Brightness.light),
        ChatixPalette.authorColor(42, Brightness.light),
      );
    });

    test('differs between themes so it stays readable on either ground', () {
      expect(
        ChatixPalette.authorColor(42, Brightness.light),
        isNot(ChatixPalette.authorColor(42, Brightness.dark)),
      );
    });

    test('spreads ids across the whole palette', () {
      final used = {
        for (var id = 0; id < ChatixPalette.authorAccents.length; id++)
          ChatixPalette.authorColor(id, Brightness.light),
      };
      expect(used, hasLength(ChatixPalette.authorAccents.length));
    });

    test('wraps instead of overflowing on a large id', () {
      final wrapped = ChatixPalette.authorColor(
        ChatixPalette.authorAccents.length + 3,
        Brightness.light,
      );
      expect(wrapped, ChatixPalette.authorColor(3, Brightness.light));
    });

    test('handles a negative id rather than throwing', () {
      expect(
        () => ChatixPalette.authorColor(-5, Brightness.light),
        returnsNormally,
      );
    });

    test('falls back to a neutral for an unknown author', () {
      expect(
        ChatixPalette.authorColor(null, Brightness.light),
        ChatixPalette.graphite400,
      );
    });
  });

  group('bubble geometry', () {
    final theme = ChatixTheme.light(ChatDensity.cosy);

    test('a lone bubble anchors on the author side', () {
      final mine = theme.bubbleBorderRadius(isMine: true);
      expect(mine.bottomRight.x, theme.bubbleAnchorRadius);
      expect(mine.bottomLeft.x, theme.bubbleRadius);

      final theirs = theme.bubbleBorderRadius(isMine: false);
      expect(theirs.bottomLeft.x, theme.bubbleAnchorRadius);
      expect(theirs.bottomRight.x, theme.bubbleRadius);
    });

    test('only the last bubble of a run keeps the anchor', () {
      final middle = theme.stackedBorderRadius(
        isMine: false,
        isFirstInGroup: false,
        isLastInGroup: false,
      );
      final last = theme.stackedBorderRadius(
        isMine: false,
        isFirstInGroup: false,
        isLastInGroup: true,
      );

      expect(last.bottomLeft.x, theme.bubbleAnchorRadius);
      expect(middle.bottomLeft.x, theme.bubbleAnchorRadius);
      // The outer edge stays soft the whole way down the run.
      expect(middle.bottomRight.x, theme.bubbleRadius);
      expect(last.bottomRight.x, theme.bubbleRadius);
    });

    test('the first bubble of a run keeps both top corners soft', () {
      final first = theme.stackedBorderRadius(
        isMine: false,
        isFirstInGroup: true,
        isLastInGroup: false,
      );
      expect(first.topLeft.x, theme.bubbleRadius);
      expect(first.topRight.x, theme.bubbleRadius);
    });
  });

  group('density', () {
    test('each step gives messages more air than the last', () {
      const order = [
        ChatDensity.compact,
        ChatDensity.cosy,
        ChatDensity.spacious,
      ];
      for (var i = 1; i < order.length; i++) {
        expect(
          order[i].bubblePaddingY,
          greaterThan(order[i - 1].bubblePaddingY),
        );
        expect(order[i].groupGap, greaterThan(order[i - 1].groupGap));
      }
    });

    test('a run is always tighter than a gap between authors', () {
      for (final density in ChatDensity.values) {
        expect(
          density.stackGap,
          lessThan(density.groupGap),
          reason: density.name,
        );
      }
    });

    test('an unknown stored value falls back to the default', () {
      expect(ChatDensity.fromName('nonsense'), ChatDensity.cosy);
      expect(ChatDensity.fromName(null), ChatDensity.cosy);
      expect(ChatDensity.fromName('compact'), ChatDensity.compact);
    });
  });

  group('AppTheme', () {
    test('carries the ChatiX extension in both brightnesses', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        expect(theme.extension<ChatixTheme>(), isNotNull);
      }
    });

    test('is violet, not the Material default blue', () {
      expect(AppTheme.lightTheme.colorScheme.primary, ChatixPalette.violet);
      expect(AppTheme.lightTheme.colorScheme.secondary, ChatixPalette.mint);
      expect(AppTheme.lightTheme.colorScheme.error, ChatixPalette.coral);
    });

    test('density reaches the theme extension', () {
      final spacious = AppTheme.light(ChatDensity.spacious);
      expect(spacious.extension<ChatixTheme>()!.density, ChatDensity.spacious);
    });

    test('uses the bundled grotesque', () {
      expect(AppTheme.lightTheme.textTheme.bodyMedium?.fontFamily, 'Manrope');
    });

    test('numeric styles ask for tabular figures so digits do not jump', () {
      final label = AppTheme.lightTheme.textTheme.labelSmall;
      expect(label?.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });
}
