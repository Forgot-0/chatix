import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/l10n/l10n.dart';
import 'package:chatix/core/router/app_routes.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.tr('language')),
            subtitle: Text(context.tr('change_language')),
            onTap: () => context.go(LanguageSettingsRoute.location),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text(context.tr('theme')),
            subtitle: Text(context.tr('change_theme')),
            onTap: () {
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(context.tr('notifications')),
            subtitle: Text(context.tr('notification_settings')),
            onTap: () {
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.tr('localization_demo')),
            subtitle: Text(context.tr('localization_demo_description')),
            onTap: () => context.go(LocalizationAssetsDemoRoute.location),
          ),
        ],
      ),
    );
  }
}
