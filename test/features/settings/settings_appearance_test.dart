import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/providers/theme_providers.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/features/settings/presentation/screens/settings_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class _AppearanceHarness extends ConsumerWidget {
  const _AppearanceHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: ref.watch(lightThemeProvider),
      darkTheme: ref.watch(darkThemeProvider),
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const _AppearanceHarness(),
      ),
    );
    await tester.pumpAndSettle();
  }

  ThemeData activeTheme(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SettingsScreen)));

  testWidgets('picking a density re-themes the app without a restart', (
    tester,
  ) async {
    await pumpSettings(tester);

    final before = activeTheme(tester);
    expect(before.extension<ChatixTheme>()!.density, AppDensity.cozy);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsScreen)),
    );
    await tester.tap(find.text(l10n.densityComfortable));
    await tester.pumpAndSettle();

    final after = activeTheme(tester);
    expect(after.extension<ChatixTheme>()!.density, AppDensity.comfortable);
    expect(after.visualDensity, isNot(before.visualDensity));
  });

  testWidgets('switching to dark repaints on the dark ground', (tester) async {
    await pumpSettings(tester);

    expect(activeTheme(tester).brightness, Brightness.light);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsScreen)),
    );
    await tester.tap(find.text(l10n.darkMode));
    await tester.pumpAndSettle();

    expect(activeTheme(tester).brightness, Brightness.dark);
  });

  testWidgets('picking an accent recolours primary everywhere', (tester) async {
    await pumpSettings(tester);

    expect(activeTheme(tester).colorScheme.primary, AppPalette.violet);

    final swatches = find.descendant(
      of: find.byType(AccentPicker),
      matching: find.byType(InkWell),
    );
    await tester.tap(swatches.at(1));
    await tester.pumpAndSettle();

    final theme = activeTheme(tester);
    expect(theme.colorScheme.primary, AppPalette.accentSeeds[1]);
    expect(
      theme.extension<ChatixTheme>()!.wallpaperSeed,
      theme.colorScheme.primary,
    );
  });

  testWidgets('resetting returns the app to the default appearance', (
    tester,
  ) async {
    await pumpSettings(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsScreen)),
    );

    await tester.tap(find.text(l10n.densityCompact));
    await tester.pumpAndSettle();
    expect(
      activeTheme(tester).extension<ChatixTheme>()!.density,
      AppDensity.compact,
    );

    await tester.ensureVisible(find.text(l10n.resetAppearance));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.resetAppearance));
    await tester.pumpAndSettle();

    expect(
      activeTheme(tester).extension<ChatixTheme>()!.density,
      AppDensity.cozy,
    );
  });
}
