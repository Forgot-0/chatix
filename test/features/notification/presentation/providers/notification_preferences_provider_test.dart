import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/features/notification/data/datasources/notification_preferences_store.dart';
import 'package:chatix/features/notification/domain/entities/notification_preferences.dart';
import 'package:chatix/features/notification/presentation/providers/notification_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> boot([
    Map<String, Object> stored = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts from what is on disk', () async {
    final container = await boot();
    await container
        .read(notificationPreferencesStoreProvider)
        .save(const NotificationPreferences(sound: false));

    final fresh = await boot({
      NotificationPreferencesStore.storageKey:
          '{"sound":false,"vibration":true,"showPreview":true}',
    });

    expect(fresh.read(notificationPreferencesProvider).sound, isFalse);
  });

  test('a change is written through immediately', () async {
    final container = await boot();

    await container
        .read(notificationPreferencesProvider.notifier)
        .setShowPreview(false);

    expect(container.read(notificationPreferencesProvider).showPreview, isFalse);
    // A push drawn from the background isolate reads the file, not the state.
    expect(
      container.read(notificationPreferencesStoreProvider).load().showPreview,
      isFalse,
    );
  });

  test('a per-chat profile is visible through the family provider', () async {
    final container = await boot();

    expect(
      container.read(chatNotificationProfileProvider('c-1')),
      ChatNotificationProfile.all,
    );

    await container
        .read(notificationPreferencesProvider.notifier)
        .setChatProfile('c-1', ChatNotificationProfile.off);

    expect(
      container.read(chatNotificationProfileProvider('c-1')),
      ChatNotificationProfile.off,
    );
  });

  test('resetting all exceptions leaves the global settings alone', () async {
    final container = await boot();
    final controller = container.read(notificationPreferencesProvider.notifier);

    await controller.setSound(false);
    await controller.setChatProfile('c-1', ChatNotificationProfile.off);
    await controller.clearChatProfiles();

    final preferences = container.read(notificationPreferencesProvider);
    expect(preferences.chatProfiles, isEmpty);
    expect(preferences.sound, isFalse);
  });

  test('quiet hours keep the half that was not changed', () async {
    final container = await boot();
    final controller = container.read(notificationPreferencesProvider.notifier);

    await controller.setQuietHoursEnabled(true);
    await controller.setQuietHours(startMinute: 22 * 60);

    final hours = container.read(notificationPreferencesProvider).quietHours;
    expect(hours.enabled, isTrue);
    expect(hours.startMinute, 22 * 60);
    expect(hours.endMinute, 7 * 60);
  });
}
