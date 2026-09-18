import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/feature_flags/feature_flag_providers.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/websocket/socket_protocol_log.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/settings/presentation/widgets/biometric_unlock_tile.dart';
import 'package:chatix/features/settings/presentation/widgets/sign_out_tile.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        key: const PageStorageKey<String>('settings-list'),
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.profile),
            subtitle: Text(l10n.profileSettingsHint),
            onTap: () => context.push(ProfileRoute.location),
          ),

          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(l10n.change_language),
            onTap: () => context.push(LanguageSettingsRoute.location),
          ),

          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.appearanceTitle),
            subtitle: Text(l10n.appearanceHint),
            onTap: () => context.push(AppearanceSettingsRoute.location),
          ),

          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: Text(l10n.notificationSettingsTitle),
            subtitle: Text(l10n.notification_settings),
            onTap: () => context.push(NotificationSettingsRoute.location),
          ),

          _SectionHeader(title: l10n.settingsSecuritySection),

          ListTile(
            leading: const Icon(Icons.devices),
            title: Text(l10n.myDevices),
            onTap: () => context.push(SessionsRoute.location),
          ),

          const BiometricUnlockTile(),

          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: Text(l10n.designSystem),
              onTap: () => context.push(ComponentShowcaseRoute.location),
            ),

          const _WsDiagnosticsTile(),

          _SectionHeader(title: l10n.settingsAccountSection),

          const SignOutTile(),
        ],
      ),
    );
  }
}

/// The label that turns a flat list of tiles into groups.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The way a recorded WebSocket session gets off the device.
///
/// Only here while `enable_ws_protocol_log` is on, which is also the only
/// time there is anything to copy — the flag gates the recording and this
/// entry together, so the app never offers to hand over a dump it does not
/// have. Copying rather than sharing because a dump belongs in the bug
/// report that is already being written, and the clipboard is the shortest
/// path into one.
class _WsDiagnosticsTile extends ConsumerWidget {
  const _WsDiagnosticsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref
        .watch(featureFlagServiceProvider)
        .getBool(kWsProtocolLogFlag, defaultValue: false);
    if (!enabled) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final log = ref.watch(socketProtocolLogProvider);

    return ListTile(
      leading: const Icon(Icons.cable_outlined),
      title: Text(l10n.wsDiagnostics),
      subtitle: Text(l10n.wsDiagnosticsFrames(log.length)),
      trailing: const Icon(Icons.copy_all_outlined),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: log.dump()));
        if (!context.mounted) return;
        AppSnackbar.quiet(context, l10n.wsDiagnosticsCopied);
      },
    );
  }
}
