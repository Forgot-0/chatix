import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/theme/theme_config.dart';

/// Reads and writes [AppearanceSettings].
///
/// Storage is one JSON blob rather than a key per field, so a settings change
/// is a single write and a partially-written state cannot happen. Anything
/// unreadable falls back to the defaults instead of throwing — a corrupt
/// preference must never keep the app from starting.
class ThemeService {
  const ThemeService(this._prefs);

  final SharedPreferences _prefs;

  static const String storageKey = 'appearance_settings';

  /// Keys written by the build that predates [AppearanceSettings]. Read once,
  /// on first load, so an upgrade keeps the theme the user already chose.
  static const String legacyThemeModeKey = 'theme_mode';
  static const String legacyDensityKey = 'chat_density';

  AppearanceSettings load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return _fromLegacyKeys();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return const AppearanceSettings();
      return AppearanceSettings.fromJson(decoded);
    } on FormatException {
      return const AppearanceSettings();
    }
  }

  Future<void> save(AppearanceSettings settings) =>
      _prefs.setString(storageKey, jsonEncode(settings.toJson()));

  Future<void> clear() => _prefs.remove(storageKey);

  AppearanceSettings _fromLegacyKeys() {
    final mode = _prefs.getString(legacyThemeModeKey);
    final density = _prefs.getString(legacyDensityKey);
    if (mode == null && density == null) return const AppearanceSettings();

    return AppearanceSettings(
      themeMode: AppThemeMode.fromName(mode),
      density: AppDensity.fromName(density),
    );
  }
}
