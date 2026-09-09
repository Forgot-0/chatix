import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/providers/theme_providers.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/ui/widgets/app_text_scale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> boot([Map<String, Object> stored = const {}]) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts from what was persisted', () async {
    final container = await boot();
    await container
        .read(appearanceProvider.notifier)
        .setThemeMode(AppThemeMode.dark);

    // A second container stands in for the next launch: same store, new state.
    final prefs = await SharedPreferences.getInstance();
    final relaunched = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(relaunched.dispose);

    expect(relaunched.read(appearanceProvider).themeMode, AppThemeMode.dark);
    expect(relaunched.read(themeModeProvider), ThemeMode.dark);
  });

  test('a density change rebuilds the theme without a restart', () async {
    final container = await boot();
    final before = container.read(lightThemeProvider);

    await container
        .read(appearanceProvider.notifier)
        .setDensity(AppDensity.comfortable);

    final after = container.read(lightThemeProvider);
    expect(after.visualDensity, isNot(before.visualDensity));
    expect(
      after.extension<ChatixTheme>()!.density,
      AppDensity.comfortable,
    );
  });

  test('an accent change reaches both themes', () async {
    final container = await boot();
    final accent = AppPalette.accentSeeds[1];

    await container.read(appearanceProvider.notifier).setAccentSeed(accent);

    expect(container.read(lightThemeProvider).colorScheme.primary, accent);
    expect(
      container.read(darkThemeProvider).colorScheme.primary,
      isNot(AppPalette.violet),
    );
  });

  test('the wallpaper and text scale are published on their own', () async {
    final container = await boot();

    await container
        .read(appearanceProvider.notifier)
        .setWallpaper(AppWallpaper.plain);
    await container.read(appearanceProvider.notifier).setTextScale(1.15);

    expect(container.read(wallpaperProvider), AppWallpaper.plain);
    expect(container.read(textScaleProvider), 1.15);
  });

  test('an out-of-range text scale is clamped before it is stored', () async {
    final container = await boot();

    await container.read(appearanceProvider.notifier).setTextScale(4);

    expect(
      container.read(textScaleProvider),
      AppearanceSettings.maxTextScale,
    );
  });

  test('reset returns every field to its default', () async {
    final container = await boot();
    final notifier = container.read(appearanceProvider.notifier);

    await notifier.setThemeMode(AppThemeMode.dark);
    await notifier.setDensity(AppDensity.compact);
    await notifier.setAccentSeed(AppPalette.coral);
    await notifier.reset();

    expect(container.read(appearanceProvider), const AppearanceSettings());
  });

  testWidgets('the app text scale multiplies the platform one', (
    tester,
  ) async {
    late TextScaler resolved;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: AppTextScale(
          scale: 1.5,
          child: Builder(
            builder: (context) {
              resolved = MediaQuery.textScalerOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // Someone who enlarged type system-wide keeps that on top of ours.
    expect(resolved.scale(10), 30);
  });

  testWidgets('a scale of one leaves the tree untouched', (tester) async {
    late TextScaler resolved;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
        child: AppTextScale(
          scale: 1,
          child: Builder(
            builder: (context) {
              resolved = MediaQuery.textScalerOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(resolved.scale(10), 12.5);
  });
}
