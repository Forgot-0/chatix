import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/notification/domain/entities/notification_preferences.dart';

/// The settings are local and nothing validates them on the way back in, so
/// the reading half has to survive whatever is on disk — including a file
/// written by an older build that knew fewer fields.
void main() {
  group('QuietHours', () {
    test('a window that wraps past midnight contains both sides of it', () {
      const hours = QuietHours(
        enabled: true,
        startMinute: 23 * 60,
        endMinute: 7 * 60,
      );

      expect(hours.containsMinute(23 * 60), isTrue);
      expect(hours.containsMinute(2 * 60), isTrue);
      expect(hours.containsMinute(6 * 60 + 59), isTrue);
      expect(hours.containsMinute(7 * 60), isFalse);
      expect(hours.containsMinute(12 * 60), isFalse);
    });

    test('a window inside one day is a plain range', () {
      const hours = QuietHours(
        enabled: true,
        startMinute: 9 * 60,
        endMinute: 17 * 60,
      );

      expect(hours.containsMinute(8 * 60 + 59), isFalse);
      expect(hours.containsMinute(9 * 60), isTrue);
      expect(hours.containsMinute(16 * 60 + 59), isTrue);
      expect(hours.containsMinute(17 * 60), isFalse);
    });

    test('start equal to end means all day', () {
      const hours = QuietHours(enabled: true, startMinute: 60, endMinute: 60);

      expect(hours.containsMinute(0), isTrue);
      expect(hours.containsMinute(13 * 60), isTrue);
    });

    test('a window that is off is never active, whatever the time', () {
      const hours = QuietHours(startMinute: 0, endMinute: 0);

      expect(hours.isActiveAt(DateTime(2026, 9, 17, 3)), isFalse);
    });

    test('isActiveAt reads the local wall clock', () {
      const hours = QuietHours(
        enabled: true,
        startMinute: 23 * 60,
        endMinute: 7 * 60,
      );

      expect(hours.isActiveAt(DateTime(2026, 9, 17, 23, 30)), isTrue);
      expect(hours.isActiveAt(DateTime(2026, 9, 17, 9)), isFalse);
    });
  });

  group('NotificationPreferences', () {
    test('everything is on by default and no chat is an exception', () {
      const preferences = NotificationPreferences();

      expect(preferences.sound, isTrue);
      expect(preferences.vibration, isTrue);
      expect(preferences.showPreview, isTrue);
      expect(preferences.quietHours.enabled, isFalse);
      expect(preferences.profileFor('chat-1'), ChatNotificationProfile.all);
    });

    test('setting a chat back to "all" removes the exception', () {
      const preferences = NotificationPreferences();

      final muted = preferences.withChatProfile(
        'chat-1',
        ChatNotificationProfile.off,
      );
      expect(muted.chatProfiles, {'chat-1': ChatNotificationProfile.off});

      final reset = muted.withChatProfile('chat-1', ChatNotificationProfile.all);
      expect(reset.chatProfiles, isEmpty);
    });

    test('survives a round trip through JSON', () {
      const preferences = NotificationPreferences(
        sound: false,
        vibration: true,
        showPreview: false,
        quietHours: QuietHours(
          enabled: true,
          startMinute: 22 * 60 + 30,
          endMinute: 6 * 60,
        ),
        chatProfiles: {
          'chat-1': ChatNotificationProfile.off,
          'chat-2': ChatNotificationProfile.mentionsOnly,
        },
      );

      final restored = NotificationPreferences.fromJson(preferences.toJson());

      expect(restored, preferences);
    });

    test('an empty object reads as the defaults', () {
      expect(
        NotificationPreferences.fromJson(const {}),
        const NotificationPreferences(),
      );
    });

    test('nonsense in the stored values does not throw', () {
      final restored = NotificationPreferences.fromJson(const {
        'sound': 'yes',
        'quietHours': {'enabled': 1, 'startMinute': 'half past', 'endMinute': -4},
        'chatProfiles': {'chat-1': 'screaming', 'chat-2': 7},
      });

      // Anything unreadable falls back rather than disappearing.
      expect(restored.sound, isTrue);
      expect(restored.quietHours.enabled, isFalse);
      expect(restored.quietHours.startMinute, 23 * 60);
      expect(restored.quietHours.endMinute, 7 * 60);
      expect(restored.profileFor('chat-1'), ChatNotificationProfile.all);
      expect(restored.profileFor('chat-2'), ChatNotificationProfile.all);
    });

    test('a chat id that is missing or blank is not an exception', () {
      const preferences = NotificationPreferences(
        chatProfiles: {'chat-1': ChatNotificationProfile.off},
      );

      expect(preferences.profileFor(null), ChatNotificationProfile.all);
      expect(preferences.profileFor(''), ChatNotificationProfile.all);
    });
  });
}
