import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/contacts/presentation/providers/blocked_users_providers.dart';
import 'package:chatix/features/settings/presentation/widgets/biometric_unlock_tile.dart';
import 'package:chatix/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Settings → Privacy: whom the reader blocked, where the account is signed
/// in, and what it takes to open the app.
///
/// Only what the API can back. "Who sees when I was last online" and "who
/// may call me" are what this screen would hold in Telegram; the backend has
/// no such settings (api-docs §4, §5.6), so there are no switches for them —
/// a switch that changes nothing is worse than none.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final blockedCount = ref.watch(blockedCountProvider);

    // `GET /users/sessions/` answers a bare `SessionDTO[]` rather than a
    // PageResult, so the count is just the length (api-docs §3.12, §0.16).
    final sessions = ref.watch(mySessionsProvider);
    final deviceCount = sessions.value?.length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacySettingsTitle)),
      body: AppContentWidth(
        child: ListView(
          children: [
            SettingsSectionHeader(title: l10n.settingsSecuritySection),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(l10n.blockedUsersTitle),
              subtitle: blockedCount == null
                  ? null
                  : Text(l10n.blockedUsersCount(blockedCount)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(BlockedUsersRoute.location),
            ),
            ListTile(
              leading: const Icon(Icons.devices_outlined),
              title: Text(l10n.privacyDevices),
              subtitle: Text(
                sessions.hasError
                    ? l10n.devicesLoadFailed
                    : deviceCount == null
                    ? l10n.loading
                    : l10n.devicesCount(deviceCount),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(SessionsRoute.location),
            ),
            SettingsSectionHeader(title: l10n.privacyPasscodeSection),
            const BiometricUnlockTile(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x1,
                AppSpacing.x4,
                AppSpacing.x6,
              ),
              child: Text(
                l10n.privacyPasscodeNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
