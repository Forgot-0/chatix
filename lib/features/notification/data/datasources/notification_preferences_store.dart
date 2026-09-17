import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/features/notification/domain/entities/notification_preferences.dart';

/// Reads and writes [NotificationPreferences].
///
/// `SharedPreferences` rather than the secure store or the server: none of
/// this is a secret, the backend has nowhere to put it (api-docs §7), and the
/// background isolate a push wakes up can open the same file without a running
/// app around it.
///
/// Anything unreadable falls back to the defaults instead of throwing — a
/// corrupt preference must never be the reason a notification is not drawn.
class NotificationPreferencesStore {
  const NotificationPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const String storageKey = 'notification_preferences';

  NotificationPreferences load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return const NotificationPreferences();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const NotificationPreferences();
      return NotificationPreferences.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } on FormatException {
      return const NotificationPreferences();
    }
  }

  Future<void> save(NotificationPreferences preferences) =>
      _prefs.setString(storageKey, jsonEncode(preferences.toJson()));

  /// Reads the settings without an app around it.
  ///
  /// The background isolate has no provider graph and no `SharedPreferences`
  /// instance handed down from `main()`, so it asks the platform itself.
  static Future<NotificationPreferences> loadStandalone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return NotificationPreferencesStore(prefs).load();
    } on Object {
      return const NotificationPreferences();
    }
  }
}
