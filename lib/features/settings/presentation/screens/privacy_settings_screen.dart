import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/contacts/presentation/providers/blocked_users_providers.dart';
import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';
import 'package:chatix/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:chatix/features/settings/presentation/utils/privacy_labels.dart';
import 'package:chatix/features/settings/presentation/widgets/biometric_unlock_tile.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Settings → Privacy: whom the reader blocked and where they are signed
/// in, who may see and do what (api-docs §4.14), and what it takes to open
/// the app.
///
/// The five rules are the server's own — `last_seen`, `photo`, `messages`,
/// `group_invites`, `calls` — each summed up the way Telegram does it, the
/// answer and the exceptions to it: "My contacts (−2, +1)".
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final blockedCount = ref.watch(blockedCountProvider);

    // `GET /users/sessions/` answers a bare `SessionDTO[]` rather than a
    // PageResult, so the count is just the length (api-docs §3.12, §0.16).
    final sessions = ref.watch(mySessionsProvider);
    final deviceCount = sessions.value?.length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacySettingsTitle)),
      body: AppContentWidth(
        child: ListView(
          key: const PageStorageKey<String>('privacy-settings'),
          padding: const EdgeInsets.only(
            top: AppSpacing.x2,
            bottom: AppSpacing.x8,
          ),
          children: [
            AppGroupedSection(
              children: [
                AppGroupedTile(
                  icon: Icons.block_rounded,
                  plateColor: AppPlatePalette.coral,
                  title: l10n.blockedUsersTitle,
                  value: blockedCount == null
                      ? null
                      : l10n.blockedUsersCount(blockedCount),
                  onTap: () => context.push(BlockedUsersRoute.location),
                ),
                AppGroupedTile(
                  icon: Icons.devices_rounded,
                  plateColor: AppPlatePalette.amber,
                  title: l10n.privacyDevices,
                  value: sessions.hasError
                      ? l10n.devicesLoadFailed
                      : deviceCount == null
                      ? l10n.loading
                      : l10n.devicesCount(deviceCount),
                  onTap: () => context.push(SessionsRoute.location),
                ),
              ],
            ),
            const SizedBox(height: SettingsLayout.groupGap),
            const _PrivacyRules(),
            const SizedBox(height: SettingsLayout.groupGap),
            AppGroupedSection(
              header: l10n.privacyPasscodeSection,
              footer: l10n.privacyPasscodeNote,
              children: const [BiometricUnlockTile()],
            ),
          ],
        ),
      ),
    );
  }
}

/// The five rules, each with where it stands — or one row that says they
/// could not be read, and asks again.
class _PrivacyRules extends ConsumerWidget {
  const _PrivacyRules();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(privacySettingsProvider);
    final value = settings.value;

    return AppGroupedSection(
      header: l10n.privacyRulesSection,
      footer: l10n.privacyRulesFooter,
      dividerIndent: AppSpacing.x4,
      children: [
        if (value == null && settings.hasError)
          AppGroupedTile(
            title: l10n.privacyRulesLoadFailed,
            subtitle: l10n.retry,
            showChevron: false,
            trailing: const Icon(Icons.refresh_rounded),
            onTap: () => ref.invalidate(privacySettingsProvider),
          )
        else
          for (final rule in PrivacyRule.values)
            AppGroupedTile(
              title: rule.title(l10n),
              value: value == null
                  ? l10n.loading
                  : privacyValueSummary(
                      l10n,
                      value.visibilityOf(rule),
                      value.exceptionsOf(rule),
                    ),
              onTap: () => context.push(PrivacyRuleRoute.locationOf(rule.slug)),
            ),
      ],
    );
  }
}
