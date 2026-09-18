import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/media_settings_providers.dart';
import 'package:chatix/core/settings/media_settings.dart';
import 'package:chatix/core/storage/cache/attachment_cache_usage.dart';
import 'package:chatix/core/theme/app_tokens.dart';
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

/// The disk budget for downloaded attachments, what it is holding right now,
/// and the one button that empties it.
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

  Future<void> _clear() async {
    if (_clearing) return;
    setState(() => _clearing = true);

    final freed = await ref.read(clearAttachmentCacheProvider)();

    if (!mounted) return;
    setState(() => _clearing = false);

    final l10n = AppLocalizations.of(context);
    AppSnackbar.quiet(
      context,
      l10n.cacheCleared(localizedByteSize(l10n, freed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final limit = ref.watch(
      mediaSettingsProvider.select((settings) => settings.cacheLimitBytes),
    );
    final usage = ref.watch(attachmentCacheUsageProvider);

    final steps = MediaSettings.cacheLimitSteps;
    // A stored limit from another build need not be one of the steps, so the
    // slider lands on the nearest one rather than refusing to draw.
    final index = _nearestStep(steps, limit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            0,
            AppSpacing.x4,
            AppSpacing.x2,
          ),
          child: Text(
            l10n.cacheLimitHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  value: index.toDouble(),
                  min: 0,
                  max: (steps.length - 1).toDouble(),
                  divisions: steps.length - 1,
                  label: localizedByteSize(l10n, steps[index]),
                  onChanged: (value) => ref
                      .read(mediaSettingsProvider.notifier)
                      .setCacheLimit(steps[value.round()]),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                localizedByteSize(l10n, steps[index]),
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x1,
            AppSpacing.x4,
            AppSpacing.x2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  switch (usage) {
                    AsyncData(:final value) when value <= 0 => l10n.cacheEmpty,
                    AsyncData(:final value) => l10n.cacheInUse(
                      localizedByteSize(l10n, value),
                    ),
                    AsyncError() => l10n.cacheEmpty,
                    _ => l10n.cacheMeasuring,
                  },
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _clearing || (usage.value ?? 0) <= 0 ? null : _clear,
                icon: _clearing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_sweep_outlined),
                label: Text(l10n.cacheClear),
              ),
            ],
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
