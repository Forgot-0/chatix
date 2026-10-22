import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/settings/presentation/providers/about_providers.dart';
import 'package:chatix/features/settings/presentation/screens/about_screen.dart';
import 'package:chatix/features/settings/presentation/screens/developer_menu_screen.dart';
import 'package:chatix/features/settings/presentation/screens/language_settings_screen.dart';

import '../../helpers/pane_frame.dart';
import '../../helpers/settings_harness.dart';

/// The sections this redesign added or rebuilt, where the shell puts them:
/// a whole phone, and beside the settings list on a desktop.
void main() {
  final sections = <String, (String, Widget)>{
    'about': (AboutSettingsRoute.location, const AboutScreen()),
    'language': (
      LanguageSettingsRoute.location,
      const LanguageSettingsScreen(),
    ),
    'developer': (DeveloperSettingsRoute.location, const DeveloperMenuScreen()),
  };

  for (final MapEntry(key: name, value: (location, screen))
      in sections.entries) {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final MapEntry(key: theme, value: dark) in {
        'light': false,
        'dark': true,
      }.entries) {
        testGoldens('$name, ${window.name}, $theme', (tester) async {
          await SettingsHarness(
            developer: true,
            links: {
              AboutLink.privacyPolicy: Uri.parse('https://example.org/privacy'),
              AboutLink.terms: Uri.parse('https://example.org/terms'),
              AboutLink.support: Uri.parse('https://example.org/support'),
            },
            screens: {location: screen},
          ).pump(tester, window: window, dark: dark, initialLocation: location);
          await screenMatchesGolden(
            tester,
            'settings_${name}_${window.name}_$theme',
          );
        });
      }
    }
  }
}
