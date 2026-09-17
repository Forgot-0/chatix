import 'package:flutter/material.dart';

import 'package:chatix/features/chat/presentation/providers/call_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Three bars that say how well a participant is getting through.
///
/// Drawn rather than lettered because it sits on top of video, where a word
/// would need a plate behind it; the label goes to screen readers instead.
/// `unknown` draws nothing at all — LiveKit reports it for the first second
/// of every join, and a grey bar there reads as a problem that is not one.
class CallQualityIndicator extends StatelessWidget {
  const CallQualityIndicator({
    super.key,
    required this.quality,
    this.size = 12,
  });

  final CallConnectionQuality quality;

  /// Height of the tallest bar.
  final double size;

  @override
  Widget build(BuildContext context) {
    if (quality == CallConnectionQuality.unknown) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final (filled, color, label) = switch (quality) {
      CallConnectionQuality.excellent => (
        3,
        scheme.secondary,
        l10n.callQualityExcellent,
      ),
      CallConnectionQuality.good => (2, scheme.secondary, l10n.callQualityGood),
      CallConnectionQuality.poor => (1, scheme.tertiary, l10n.callQualityPoor),
      CallConnectionQuality.lost => (0, scheme.error, l10n.callQualityLost),
      CallConnectionQuality.unknown => (0, scheme.outline, ''),
    };

    final barWidth = size / 4;

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        height: size,
        width: barWidth * 5,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: barWidth / 2),
              Container(
                width: barWidth,
                height: size * (0.45 + 0.275 * i),
                decoration: BoxDecoration(
                  color: i < filled
                      ? color
                      : scheme.onSurface.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(barWidth / 2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
