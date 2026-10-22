import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/media_settings_providers.dart';
import 'package:chatix/core/settings/media_settings.dart';
import 'package:chatix/core/storage/cache/attachment_cache_usage.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

const int _mebibyte = 1024 * 1024;
const int _gibibyte = 1024 * _mebibyte;

/// A byte count in the reader's language.
///
/// Rounds hard on purpose: a cache is a rough quantity, and "1.5 GB" is
/// easier to hold in mind than "1.47 GB".
String localizedByteSize(AppLocalizations l10n, int bytes) {
  if (bytes < _gibibyte) {
    return l10n.sizeMegabytes('${(bytes / _mebibyte).round()}');
  }

  final gigabytes = bytes / _gibibyte;
  final rounded = (gigabytes * 10).round() / 10;
  return l10n.sizeGigabytes(
    rounded == rounded.roundToDouble()
        ? '${rounded.round()}'
        : rounded.toStringAsFixed(1),
  );
}

/// What the attachment cache holds against its budget, the budget itself,
/// and the one button that empties it — one card in Data and storage.
///
/// The figure is measured, not remembered: the cache directory is one the OS
/// may empty on its own, so anything else would eventually lie about what
/// pressing "clear" will free.
class CacheSettingsSection extends ConsumerStatefulWidget {
  const CacheSettingsSection({super.key});

  @override
  ConsumerState<CacheSettingsSection> createState() =>
      _CacheSettingsSectionState();
}

class _CacheSettingsSectionState extends ConsumerState<CacheSettingsSection> {
  bool _clearing = false;

  /// Asks first. Nothing is lost for good — every file comes down again
  /// when it is opened — but a phone on mobile data pays for that, and the
  /// dialog is where the reader learns that they are not deleting messages.
  Future<void> _clear(int used) async {
    if (_clearing) return;
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.dataStorageClearConfirmTitle),
        content: Text(
          l10n.dataStorageClearConfirmBody(localizedByteSize(l10n, used)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.cacheClear),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    final freed = await ref.read(clearAttachmentCacheProvider)();
    if (!mounted) return;
    setState(() => _clearing = false);

    AppSnackbar.quiet(
      context,
      l10n.cacheCleared(localizedByteSize(l10n, freed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final limit = ref.watch(
      mediaSettingsProvider.select((settings) => settings.cacheLimitBytes),
    );
    final usage = ref.watch(attachmentCacheUsageProvider);

    final steps = MediaSettings.cacheLimitSteps;
    // A stored limit from another build need not be one of the steps, so the
    // slider lands on the nearest one rather than refusing to draw.
    final index = _nearestStep(steps, limit);
    final limitLabel = localizedByteSize(l10n, steps[index]);

    final used = switch (usage) {
      AsyncData(:final value) => value,
      AsyncError() => 0,
      _ => null,
    };
    final canClear = !_clearing && used != null && used > 0;

    return AppGroupedSection(
      header: l10n.dataStorageUsageSection,
      footer: l10n.cacheLimitHint,
      dividerIndent: AppSpacing.x4,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x3,
            AppSpacing.x4,
            AppSpacing.x4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.dataStorageCacheTitle,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  Text(
                    switch (used) {
                      null => l10n.cacheMeasuring,
                      <= 0 => l10n.cacheEmpty,
                      final bytes => l10n.dataStorageUsageOf(
                        localizedByteSize(l10n, bytes),
                        limitLabel,
                      ),
                    },
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.full),
                child: LinearProgressIndicator(
                  value: used == null
                      ? null
                      : (used / steps[index]).clamp(0.0, 1.0),
                  minHeight: SettingsLayout.usageBarHeight,
                  color: scheme.primary,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x2,
            AppSpacing.x4,
            AppSpacing.x1,
          ),
          child: Row(
            children: [
              Text(l10n.cacheLimit, style: theme.textTheme.bodyLarge),
              Expanded(
                child: Slider(
                  value: index.toDouble(),
                  min: 0,
                  max: (steps.length - 1).toDouble(),
                  divisions: steps.length - 1,
                  label: limitLabel,
                  onChanged: (value) => ref
                      .read(mediaSettingsProvider.notifier)
                      .setCacheLimit(steps[value.round()]),
                ),
              ),
              Text(limitLabel, style: theme.textTheme.labelLarge),
            ],
          ),
        ),
        AppGroupedTile(
          title: l10n.cacheClear,
          showChevron: false,
          enabled: canClear,
          onTap: canClear ? () => _clear(used) : null,
          trailing: _clearing
              ? const SizedBox.square(
                  dimension: SettingsLayout.rowSpinner,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.delete_sweep_outlined,
                  color: canClear ? scheme.primary : theme.disabledColor,
                ),
        ),
      ],
    );
  }

  static int _nearestStep(List<int> steps, int value) {
    var best = 0;
    var bestDistance = (steps.first - value).abs();
    for (var i = 1; i < steps.length; i++) {
      final distance = (steps[i] - value).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }
}
