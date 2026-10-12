import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/feature_flags/feature_flag_providers.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/settings/send_shortcut.dart';
import 'package:chatix/core/ui/desktop/desktop_input.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/core/websocket/socket_protocol_log.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:chatix/features/settings/presentation/widgets/sign_out_tile.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: AppContentWidth(
        child: ListView(
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

            // Blocked users, devices and the app lock live one level down,
            // the way Telegram groups them.
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(l10n.privacySettingsTitle),
              subtitle: Text(l10n.privacySettingsHint),
              onTap: () => context.push(PrivacySettingsRoute.location),
            ),

            if (kDebugMode)
              ListTile(
                leading: const Icon(Icons.widgets_outlined),
                title: Text(l10n.designSystem),
                onTap: () => context.push(ComponentShowcaseRoute.location),
              ),

            const _WsDiagnosticsTile(),

            // A physical keyboard's own question; a phone has no Enter to
            // send with.
            if (DesktopInput.isDesktop) ...[
              SettingsSectionHeader(title: l10n.settingsKeyboardSection),
              const _SendShortcutTile(),
            ],

            SettingsSectionHeader(title: l10n.settingsAccountSection),

            const SignOutTile(),
          ],
        ),
      ),
    );
  }
}

/// Enter or Ctrl+Enter (Cmd+Enter on a Mac) to send.
///
/// Worded as the switch's "on": sending with the modifier is the choice
/// somebody makes on purpose, and the line under it says what each key
/// does now, so nobody has to remember which way round the default was.
class _SendShortcutTile extends ConsumerWidget {
  const _SendShortcutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final modifier = DesktopInput.usesCommandKey
        ? l10n.keyboardCommandKey
        : l10n.keyboardControlKey;
    final withModifier =
        ref.watch(sendShortcutProvider) == SendShortcut.modifierEnter;

    return SwitchListTile(
      secondary: const Icon(Icons.keyboard_return_rounded),
      title: Text(l10n.settingsSendWithModifierEnter(modifier)),
      subtitle: Text(
        withModifier
            ? l10n.settingsSendWithModifierEnterOn(modifier)
            : l10n.settingsSendWithModifierEnterOff,
      ),
      value: withModifier,
      onChanged: (value) => ref
          .read(sendShortcutProvider.notifier)
          .set(value ? SendShortcut.modifierEnter : SendShortcut.enter),
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
