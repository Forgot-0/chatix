import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/feature_flags/feature_flag_providers.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/settings/dev_menu.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/core/websocket/socket_protocol_log.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The hidden menu seven taps on the version open: the design-system
/// showcase and the WebSocket recording, for whoever is checking a build —
/// a release one included.
///
/// Nothing here touches the account. Recording is for this run only and
/// stops when the menu is hidden; the dump goes to the clipboard because
/// it belongs in the bug report that is already being written.
class DeveloperMenuScreen extends ConsumerWidget {
  const DeveloperMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Recording is on when the server asked for it for this account, or
    // when the switch below did for this run. The switch cannot turn off
    // what the server turned on.
    final byFlag = ref
        .watch(featureFlagServiceProvider)
        .getBool(kWsProtocolLogFlag, defaultValue: false);
    final bySwitch = ref.watch(socketRecordingSwitchProvider);
    final recording = byFlag || bySwitch;
    final log = ref.watch(socketProtocolLogProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devMenuTitle)),
      body: AppContentWidth(
        child: ListView(
          key: const PageStorageKey<String>('developer-menu'),
          padding: const EdgeInsets.only(
            top: AppSpacing.x2,
            bottom: AppSpacing.x8,
          ),
          children: [
            AppGroupedSection(
              footer: l10n.devMenuNote,
              children: [
                AppGroupedTile(
                  icon: Icons.widgets_rounded,
                  plateColor: AppPlatePalette.violet,
                  title: l10n.designSystem,
                  subtitle: l10n.designSystemHint,
                  onTap: () => context.push(ComponentShowcaseRoute.location),
                ),
              ],
            ),
            const SizedBox(height: SettingsLayout.groupGap),
            AppGroupedSection(
              children: [
                AppGroupedSwitchTile(
                  icon: Icons.fiber_manual_record_rounded,
                  plateColor: AppPlatePalette.coral,
                  title: l10n.devMenuRecordSocket,
                  subtitle: byFlag
                      ? l10n.devMenuRecordSocketByFlag
                      : l10n.devMenuRecordSocketHint,
                  value: recording,
                  onChanged: byFlag
                      ? null
                      : ref.read(socketRecordingSwitchProvider.notifier).set,
                ),
                AppGroupedTile(
                  icon: Icons.cable_rounded,
                  plateColor: AppPlatePalette.azure,
                  title: l10n.wsDiagnostics,
                  subtitle: l10n.wsDiagnosticsFrames(log.length),
                  enabled: recording,
                  trailing: const Icon(Icons.copy_all_outlined),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: log.dump()));
                    if (!context.mounted) return;
                    AppSnackbar.quiet(context, l10n.wsDiagnosticsCopied);
                  },
                ),
              ],
            ),
            const SizedBox(height: SettingsLayout.groupGap),
            AppGroupedSection(
              children: [
                AppGroupedTile(
                  icon: Icons.visibility_off_rounded,
                  plateColor: AppPlatePalette.graphite,
                  title: l10n.devMenuHide,
                  showChevron: false,
                  onTap: () async {
                    await ref.read(devMenuUnlockedProvider.notifier).hide();
                    if (!context.mounted) return;
                    AppSnackbar.quiet(context, l10n.devMenuHidden);
                    context.go(SettingsRoute.location);
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
