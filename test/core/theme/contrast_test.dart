import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';

/// WCAG AA: 4.5:1 for body text, 3:1 for text at 18pt / 14pt bold and above,
/// and for the boundary of a control you have to be able to find.
const double _aaText = 4.5;
const double _aaLarge = 3.0;

/// What a translucent foreground actually looks like once it is painted.
///
/// Half the palette is `foreground.withValues(alpha: …)` over a bubble, and
/// the ratio that matters is the one after compositing — measuring the
/// unblended colour flatters every one of them.
Color _on(Color background, Color foreground) =>
    Color.alphaBlend(foreground, background);

void main() {
  void expectReadable(
    Color background,
    Color foreground, {
    required String what,
    double minimum = _aaText,
  }) {
    final ratio = AppContrast.ratio(background, _on(background, foreground));
    expect(
      ratio,
      greaterThanOrEqualTo(minimum),
      reason:
          '$what is ${ratio.toStringAsFixed(2)}:1, '
          'below the ${minimum.toStringAsFixed(1)}:1 it needs',
    );
  }

  group('the conversation reads in both themes', () {
    for (final entry in {
      'light': (ChatixTheme.light(), AppTheme.lightTheme.colorScheme),
      'dark': (ChatixTheme.dark(), AppTheme.darkTheme.colorScheme),
    }.entries) {
      final name = entry.key;
      final (chatix, scheme) = entry.value;

      test('$name: what somebody else said', () {
        expectReadable(
          chatix.bubbleIncoming,
          chatix.bubbleIncomingForeground,
          what: '$name incoming body text',
        );
      });

      test('$name: what you said, at both ends of the gradient', () {
        for (final stop in chatix.bubbleOutgoingGradient.colors) {
          expectReadable(
            stop,
            chatix.bubbleOutgoingForeground,
            what: '$name outgoing body text on $stop',
          );
        }
      });

      // The clock, the "edited" mark and the ticks are all drawn at
      // `foreground.withValues(alpha: 0.66)` — small text, so AA asks the
      // full 4.5:1 of them, and the alpha is exactly what could sink it.
      test('$name: the clock and the ticks on a bubble', () {
        expectReadable(
          chatix.bubbleIncoming,
          chatix.bubbleIncomingMuted,
          what: '$name incoming meta row',
        );

        for (final stop in chatix.bubbleOutgoingGradient.colors) {
          expectReadable(
            stop,
            chatix.bubbleOutgoingMuted,
            what: '$name outgoing meta row on $stop',
          );
        }
      });

      test('$name: the day separator over the wallpaper', () {
        expectReadable(
          Color.alphaBlend(chatix.dateChip, chatix.chatBackground),
          scheme.onSurfaceVariant,
          what: '$name date chip label',
        );
      });

      test('$name: the author name over a group bubble', () {
        for (var id = 0; id < chatix.authorPalette.length; id++) {
          expectReadable(
            chatix.bubbleIncoming,
            chatix.authorColor(id),
            // Author names are labelMedium bold, which AA counts as large.
            what: '$name author accent $id',
            minimum: _aaLarge,
          );
        }
      });

      test('$name: secondary text on every surface it is used on', () {
        for (final ground in <(String, Color)>[
          ('surface', scheme.surface),
          ('chat background', chatix.chatBackground),
          ('composer', chatix.composerSurface),
        ]) {
          expectReadable(
            ground.$2,
            scheme.onSurfaceVariant,
            what: '$name onSurfaceVariant on ${ground.$1}',
          );
        }
      });

      test('$name: a reaction chip can be told apart from its bubble', () {
        for (final chip in [chatix.reactionChip, chatix.reactionChipSelected]) {
          final painted = Color.alphaBlend(chip, chatix.bubbleIncoming);
          expect(
            AppContrast.ratio(painted, chatix.bubbleIncoming),
            greaterThan(1.0),
            reason: '$name reaction chip is invisible on its bubble',
          );
          expectReadable(
            painted,
            scheme.onSurface,
            what: '$name reaction count on a chip',
          );
        }
      });

      test('$name: an error still reads', () {
        expectReadable(
          scheme.surface,
          scheme.error,
          what: '$name error text on surface',
        );
      });
    }
  });

  // Somebody who picks a different accent should not lose the clock inside
  // their own bubbles.
  group('every accent the picker offers', () {
    for (final seed in AppPalette.accentSeeds) {
      for (final brightness in Brightness.values) {
        test('$seed on ${brightness.name}', () {
          final theme = ChatixTheme.fromScheme(
            scheme: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: brightness,
            ),
            density: AppDensity.cozy,
            accent: seed,
          );

          for (final stop in theme.bubbleOutgoingGradient.colors) {
            expectReadable(
              stop,
              theme.bubbleOutgoingForeground,
              what: 'outgoing text on $stop',
            );
            expectReadable(
              stop,
              theme.bubbleOutgoingMuted,
              what: 'outgoing meta on $stop',
            );
          }
        });
      }
    }
  });
}
