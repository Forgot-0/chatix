import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/settings/dev_menu.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/brand/chatix_logo.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/settings/presentation/providers/about_providers.dart';
import 'package:chatix/features/settings/presentation/widgets/whats_new_sheet.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Settings → About: which build this is, what it brought, where the
/// policies live, and whose code it is made of.
///
/// The version row is also the door to the developer menu: seven taps in a
/// row open it, in a release build as much as in a debug one, and the
/// choice is remembered on the device.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  final DevMenuTapCounter _taps = DevMenuTapCounter();

  Future<void> _onVersionTap() async {
    final l10n = AppLocalizations.of(context);

    if (ref.read(devMenuUnlockedProvider)) {
      AppSnackbar.quiet(context, l10n.devMenuAlreadyOpen);
      return;
    }

    final left = _taps.tap();
    if (left == 0) {
      _taps.reset();
      await ref.read(devMenuUnlockedProvider.notifier).unlock();
      if (!mounted) return;
      AppSnackbar.quiet(context, l10n.devMenuUnlocked);
      return;
    }
    if (left <= DevMenuTapCounter.hintFrom) {
      AppSnackbar.quiet(context, l10n.devMenuTapsLeft(left));
    }
  }

  Future<void> _openLink(Uri uri) async {
    final l10n = AppLocalizations.of(context);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) AppSnackbar.failure(context, l10n.aboutLinkFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final version = ref.watch(appVersionProvider).value;
    final links = ref.watch(aboutLinksProvider);
    final versionLabel = version == null
        ? null
        : l10n.aboutVersionValue(version.version, version.build);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: AppContentWidth(
        child: ListView(
          key: const PageStorageKey<String>('about'),
          padding: const EdgeInsets.only(
            top: AppSpacing.x6,
            bottom: AppSpacing.x8,
          ),
          children: [
            const Center(child: ChatixLogo(size: SettingsLayout.aboutLogo)),
            const SizedBox(height: AppSpacing.x3),
            Text(
              AppConstants.appName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              l10n.aboutTagline,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.x6),
            AppGroupedSection(
              children: [
                AppGroupedTile(
                  icon: Icons.tag_rounded,
                  plateColor: AppPlatePalette.graphite,
                  title: l10n.aboutVersion,
                  value: versionLabel ?? l10n.loading,
                  showChevron: false,
                  onTap: _onVersionTap,
                ),
                AppGroupedTile(
                  icon: Icons.auto_awesome_rounded,
                  plateColor: AppPlatePalette.violet,
                  title: l10n.aboutWhatsNew,
                  onTap: () =>
                      showWhatsNewSheet(context, version: version?.version),
                ),
              ],
            ),
            const SizedBox(height: SettingsLayout.groupGap),
            AppGroupedSection(
              children: [
                for (final MapEntry(key: link, value: uri) in links.entries)
                  AppGroupedTile(
                    icon: switch (link) {
                      AboutLink.privacyPolicy => Icons.shield_rounded,
                      AboutLink.terms => Icons.gavel_rounded,
                      AboutLink.support => Icons.help_rounded,
                    },
                    plateColor: switch (link) {
                      AboutLink.privacyPolicy => AppPlatePalette.azure,
                      AboutLink.terms => AppPlatePalette.clay,
                      AboutLink.support => AppPlatePalette.mint,
                    },
                    title: switch (link) {
                      AboutLink.privacyPolicy => l10n.aboutPrivacyPolicy,
                      AboutLink.terms => l10n.aboutTerms,
                      AboutLink.support => l10n.aboutSupport,
                    },
                    trailing: Icon(
                      Icons.open_in_new_rounded,
                      size: SettingsLayout.plateIcon,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onTap: () => _openLink(uri),
                  ),
                AppGroupedTile(
                  icon: Icons.description_rounded,
                  plateColor: AppPlatePalette.moss,
                  title: l10n.aboutLicenses,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppConstants.appName,
                    applicationVersion: versionLabel,
                    applicationIcon: const Padding(
                      padding: EdgeInsets.all(AppSpacing.x2),
                      child: ChatixLogo(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
