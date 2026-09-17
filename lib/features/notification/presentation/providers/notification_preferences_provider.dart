import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/features/notification/data/datasources/notification_preferences_store.dart';
import 'package:chatix/features/notification/domain/entities/notification_preferences.dart';

final notificationPreferencesStoreProvider =
    Provider<NotificationPreferencesStore>((ref) {
      return NotificationPreferencesStore(ref.watch(sharedPreferencesProvider));
    });

/// The reader's own notification settings, and the only place they are set.
///
/// Local by necessity: api-docs §7 has endpoints for devices, a list and a
/// read flag, and nothing that would store any of this. Written through to
/// `SharedPreferences` on every change so the background isolate that draws a
/// push while the app is closed reads the same answers.
class NotificationPreferencesController
    extends Notifier<NotificationPreferences> {
  @override
  NotificationPreferences build() =>
      ref.watch(notificationPreferencesStoreProvider).load();

  Future<void> setSound(bool value) => _apply(state.copyWith(sound: value));

  Future<void> setVibration(bool value) =>
      _apply(state.copyWith(vibration: value));

  Future<void> setShowPreview(bool value) =>
      _apply(state.copyWith(showPreview: value));

  Future<void> setQuietHoursEnabled(bool value) =>
      _apply(state.copyWith(quietHours: state.quietHours.copyWith(enabled: value)));

  Future<void> setQuietHours({int? startMinute, int? endMinute}) => _apply(
    state.copyWith(
      quietHours: state.quietHours.copyWith(
        startMinute: startMinute,
        endMinute: endMinute,
      ),
    ),
  );

  Future<void> setChatProfile(String chatId, ChatNotificationProfile profile) =>
      _apply(state.withChatProfile(chatId, profile));

  Future<void> clearChatProfiles() =>
      _apply(state.copyWith(chatProfiles: const {}));

  Future<void> _apply(NotificationPreferences next) async {
    if (next == state) return;
    state = next;
    await ref.read(notificationPreferencesStoreProvider).save(next);
  }
}

final notificationPreferencesProvider =
    NotifierProvider<
      NotificationPreferencesController,
      NotificationPreferences
    >(NotificationPreferencesController.new);

/// What one chat is set to, without rebuilding on every unrelated change.
final chatNotificationProfileProvider =
    Provider.family<ChatNotificationProfile, String>((ref, chatId) {
      return ref.watch(
        notificationPreferencesProvider.select(
          (preferences) => preferences.profileFor(chatId),
        ),
      );
    });
