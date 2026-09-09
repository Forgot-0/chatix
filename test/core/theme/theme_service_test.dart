import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/theme/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ThemeService> serviceWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return ThemeService(await SharedPreferences.getInstance());
  }

  test('an empty store loads the defaults', () async {
    final service = await serviceWith({});
    expect(service.load(), const AppearanceSettings());
  });

  test('what is saved is what comes back', () async {
    final service = await serviceWith({});
    const settings = AppearanceSettings(
      themeMode: AppThemeMode.dark,
      density: AppDensity.comfortable,
      accentSeed: AppPalette.amber,
      wallpaperId: 'plain',
      textScale: 1.15,
    );

    await service.save(settings);

    expect(service.load(), settings);
  });

  test('a corrupt blob falls back instead of throwing', () async {
    final service = await serviceWith({
      ThemeService.storageKey: 'not json at all',
    });

    expect(service.load(), const AppearanceSettings());
  });

  test('a blob of the wrong shape falls back too', () async {
    final service = await serviceWith({ThemeService.storageKey: '[1,2,3]'});

    expect(service.load(), const AppearanceSettings());
  });

  test('an upgrade keeps the theme chosen under the old keys', () async {
    final service = await serviceWith({
      ThemeService.legacyThemeModeKey: 'dark',
      ThemeService.legacyDensityKey: 'spacious',
    });

    final settings = service.load();
    expect(settings.themeMode, AppThemeMode.dark);
    expect(settings.density, AppDensity.comfortable);
    expect(settings.accentSeed, AppPalette.violet);
  });

  test('the new blob wins over stale legacy keys', () async {
    final service = await serviceWith({
      ThemeService.legacyThemeModeKey: 'dark',
      ThemeService.legacyDensityKey: 'compact',
    });

    await service.save(const AppearanceSettings(themeMode: AppThemeMode.light));

    expect(service.load().themeMode, AppThemeMode.light);
    expect(service.load().density, AppDensity.cozy);
  });

  test('clearing returns the store to the defaults', () async {
    final service = await serviceWith({});
    await service.save(
      const AppearanceSettings(themeMode: AppThemeMode.dark),
    );

    await service.clear();

    expect(service.load(), const AppearanceSettings());
  });
}
