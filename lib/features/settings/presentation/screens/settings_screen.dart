import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/chat_density_provider.dart';
import 'package:chatix/core/theme/theme_mode_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final density = ref.watch(chatDensityProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(l10n.change_language),
            onTap: () => context.go(LanguageSettingsRoute.location),
          ),

          const Divider(),

          _SectionLabel(label: l10n.theme),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeModeProvider.notifier).set(mode);
              }
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text(l10n.systemMode),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text(l10n.lightMode),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text(l10n.darkMode),
                ),
              ],
            ),
          ),

          const Divider(),

          _SectionLabel(label: l10n.messageDensity),
          RadioGroup<ChatDensity>(
            groupValue: density,
            onChanged: (value) {
              if (value != null) {
                ref.read(chatDensityProvider.notifier).set(value);
              }
            },
            child: Column(
              children: [
                RadioListTile<ChatDensity>(
                  value: ChatDensity.compact,
                  title: Text(l10n.densityCompact),
                ),
                RadioListTile<ChatDensity>(
                  value: ChatDensity.cosy,
                  title: Text(l10n.densityCosy),
                ),
                RadioListTile<ChatDensity>(
                  value: ChatDensity.spacious,
                  title: Text(l10n.densitySpacious),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
