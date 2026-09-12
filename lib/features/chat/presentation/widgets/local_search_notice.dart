import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Says that a message search only covers what this device has loaded.
///
/// It is on screen because the API has no message search (api-docs §5.4) and
/// pretending otherwise would be the one thing worse than the limitation:
/// someone searching for a word they remember, finding nothing, and
/// concluding the message is gone. The day a server search lands, the result
/// stops reporting `MessageSearchSource.localCache` and this never renders.
class LocalSearchNotice extends StatelessWidget {
  const LocalSearchNotice({super.key, this.compact = false});

  /// The one-line form, for the strip under an in-chat search field.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (compact) {
      return Text(
        l10n.searchLoadedHistoryOnly,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        AppSpacing.x1,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.downloading_outlined,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.searchLoadedHistoryOnly,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.searchLoadedHistoryExplained,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
