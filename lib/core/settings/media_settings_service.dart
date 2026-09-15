import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/settings/media_settings.dart';

/// Reads and writes [MediaSettings].
///
/// Anything unreadable falls back to the defaults rather than throwing: a
/// corrupt preference must never keep the app from starting, and the default
/// here is the cautious one anyway.
class MediaSettingsService {
  const MediaSettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const String storageKey = 'media_settings';

  MediaSettings load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return const MediaSettings();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return const MediaSettings();
      return MediaSettings.fromJson(decoded);
    } on FormatException {
      return const MediaSettings();
    }
  }

  Future<void> save(MediaSettings settings) =>
      _prefs.setString(storageKey, jsonEncode(settings.toJson()));
}
