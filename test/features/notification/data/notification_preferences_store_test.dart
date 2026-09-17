import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/features/notification/data/datasources/notification_preferences_store.dart';
import 'package:chatix/features/notification/domain/entities/notification_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<NotificationPreferencesStore> boot([
    Map<String, Object> stored = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(stored);
    return NotificationPreferencesStore(await SharedPreferences.getInstance());
  }

  test('an untouched install reads as the defaults', () async {
    final store = await boot();

    expect(store.load(), const NotificationPreferences());
  });

  test('what was saved is what comes back', () async {
    final store = await boot();

    const preferences = NotificationPreferences(
      sound: false,
      showPreview: false,
      quietHours: QuietHours(enabled: true, startMinute: 60, endMinute: 420),
      chatProfiles: {'c-1': ChatNotificationProfile.mentionsOnly},
    );

    await store.save(preferences);

    expect(store.load(), preferences);
  });

  test('a corrupt preference falls back instead of throwing', () async {
    final store = await boot({
      NotificationPreferencesStore.storageKey: 'not json at all',
    });

    expect(store.load(), const NotificationPreferences());
  });

  test('a preference that is not an object falls back too', () async {
    final store = await boot({
      NotificationPreferencesStore.storageKey: '[1, 2, 3]',
    });

    expect(store.load(), const NotificationPreferences());
  });

  test('the background isolate reads the same settings', () async {
    final store = await boot();
    await store.save(const NotificationPreferences(vibration: false));

    // No provider graph, no app: exactly what a push wakes up into.
    final loaded = await NotificationPreferencesStore.loadStandalone();

    expect(loaded.vibration, isFalse);
  });
}
