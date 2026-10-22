import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/media_settings_providers.dart';
import 'package:chatix/core/settings/media_settings.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/settings/presentation/widgets/cache_settings.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Settings → Data and storage: what the app fetches on its own, over
/// which network, and how much of the disk it may keep.
///
/// Auto-download is stored as one of three answers per kind of attachment
/// ([MediaAutoDownload]) and drawn the way people think about it — a
/// switch per kind for mobile data, and another for Wi-Fi. The two are
/// tied: anything fetched over mobile data is fetched over Wi-Fi too, so
/// the switches can never describe a fourth answer the setting does not
/// have.
class DataStorageScreen extends ConsumerWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dataStorageTitle)),
      body: AppContentWidth(
        child: ListView(
          key: const PageStorageKey<String>('data-storage'),
          padding: const EdgeInsets.only(
            top: AppSpacing.x2,
            bottom: AppSpacing.x8,
          ),
          children: [
            const CacheSettingsSection(),
            const SizedBox(height: SettingsLayout.groupGap),
            AppGroupedSection(
              header: l10n.autoDownloadOnMobile,
              footer: l10n.dataStorageAutoDownloadFooter,
              dividerIndent: AppSpacing.x4,
              children: [
                for (final kind in MediaKind.values)
                  _AutoDownloadSwitch(kind: kind, mobile: true),
              ],
            ),
            const SizedBox(height: SettingsLayout.groupGap),
            AppGroupedSection(
              header: l10n.autoDownloadOnWifi,
              footer: l10n.autoDownloadHint,
              dividerIndent: AppSpacing.x4,
              children: [
                for (final kind in MediaKind.values)
                  _AutoDownloadSwitch(kind: kind, mobile: false),
              ],
            ),
            const SizedBox(height: SettingsLayout.groupGap),
            AppGroupedSection(
              header: l10n.mediaAutoplay,
              footer: l10n.mediaAutoplayHint,
              children: const [_AutoplayChoice()],
            ),
            const SizedBox(height: SettingsLayout.groupGap),
            AppGroupedSection(
              children: [
                AppGroupedTile(
                  icon: Icons.restart_alt_rounded,
                  plateColor: AppPlatePalette.graphite,
                  title: l10n.dataStorageReset,
                  showChevron: false,
                  onTap: () async {
                    await ref
                        .read(mediaSettingsProvider.notifier)
                        .resetAutoDownload();
                    if (!context.mounted) return;
                    AppSnackbar.quiet(context, l10n.dataStorageResetDone);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One kind of attachment on one kind of network.
class _AutoDownloadSwitch extends ConsumerWidget {
  const _AutoDownloadSwitch({required this.kind, required this.mobile});

  final MediaKind kind;

  /// The mobile-data switch; the Wi-Fi one otherwise.
  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final policy = ref.watch(
      mediaSettingsProvider.select((settings) => settings.policyFor(kind)),
    );

    return AppGroupedSwitchTile(
      title: switch (kind) {
        MediaKind.photo => l10n.autoDownloadPhotos,
        MediaKind.video => l10n.autoDownloadVideos,
        MediaKind.file => l10n.autoDownloadFiles,
        MediaKind.voice => l10n.autoDownloadVoice,
      },
      value: mobile ? policy.onMobile : policy.onWifi,
      onChanged: (enabled) => ref
          .read(mediaSettingsProvider.notifier)
          .setAutoDownload(
            kind,
            mobile ? policy.withMobile(enabled) : policy.withWifi(enabled),
          ),
    );
  }
}

/// When a video note starts playing by itself: three answers, side by side.
class _AutoplayChoice extends ConsumerWidget {
  const _AutoplayChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final autoplay = ref.watch(
      mediaSettingsProvider.select((s) => s.videoNoteAutoplay),
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: SegmentedButton<MediaAutoplay>(
        segments: [
          ButtonSegment(
            value: MediaAutoplay.always,
            label: Text(l10n.mediaAutoplayAlways),
          ),
          ButtonSegment(
            value: MediaAutoplay.wifiOnly,
            label: Text(l10n.mediaAutoplayWifi),
          ),
          ButtonSegment(
            value: MediaAutoplay.never,
            label: Text(l10n.mediaAutoplayNever),
          ),
        ],
        selected: {autoplay},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => ref
            .read(mediaSettingsProvider.notifier)
            .setVideoNoteAutoplay(selection.first),
      ),
    );
  }
}
