import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/notification/domain/entities/notification_preferences.dart';
import 'package:chatix/features/notification/domain/usecases/resolve_notification_display_use_case.dart';

/// None of this is on the server (api-docs §7 has no settings endpoint), so
/// this use case is the only thing standing between a push and the reader.
void main() {
  const useCase = ResolveNotificationDisplayUseCase();

  final noon = DateTime(2026, 9, 17, 12);
  final night = DateTime(2026, 9, 17, 23, 30);

  test('a chat with no exception shows, sounds and previews', () {
    final decision = useCase.execute(
      preferences: const NotificationPreferences(),
      chatId: 'chat-1',
      now: noon,
    );

    expect(decision.show, isTrue);
    expect(decision.playSound, isTrue);
    expect(decision.vibrate, isTrue);
    expect(decision.showPreview, isTrue);
  });

  test('a chat set to "nothing" draws nothing at all', () {
    final decision = useCase.execute(
      preferences: const NotificationPreferences(
        chatProfiles: {'chat-1': ChatNotificationProfile.off},
      ),
      chatId: 'chat-1',
      now: noon,
    );

    expect(decision.show, isFalse);
  });

  test('"mentions only" lets a mention through and swallows the rest', () {
    const preferences = NotificationPreferences(
      chatProfiles: {'chat-1': ChatNotificationProfile.mentionsOnly},
    );

    expect(
      useCase
          .execute(preferences: preferences, chatId: 'chat-1', now: noon)
          .show,
      isFalse,
    );
    expect(
      useCase
          .execute(
            preferences: preferences,
            chatId: 'chat-1',
            isMention: true,
            now: noon,
          )
          .show,
      isTrue,
    );
  });

  test('a per-chat profile does not apply to a system notice', () {
    final decision = useCase.execute(
      preferences: const NotificationPreferences(
        chatProfiles: {'chat-1': ChatNotificationProfile.off},
      ),
      chatId: 'chat-1',
      isSystem: true,
      now: noon,
    );

    expect(decision.show, isTrue);
  });

  test('quiet hours silence rather than swallow', () {
    final decision = useCase.execute(
      preferences: const NotificationPreferences(
        quietHours: QuietHours(
          enabled: true,
          startMinute: 23 * 60,
          endMinute: 7 * 60,
        ),
      ),
      chatId: 'chat-1',
      now: night,
    );

    expect(decision.show, isTrue);
    expect(decision.playSound, isFalse);
    expect(decision.vibrate, isFalse);
  });

  test('outside the quiet window the sound comes back', () {
    final decision = useCase.execute(
      preferences: const NotificationPreferences(
        quietHours: QuietHours(
          enabled: true,
          startMinute: 23 * 60,
          endMinute: 7 * 60,
        ),
      ),
      chatId: 'chat-1',
      now: noon,
    );

    expect(decision.playSound, isTrue);
  });

  test('sound and vibration are answered separately', () {
    final decision = useCase.execute(
      preferences: const NotificationPreferences(sound: false),
      chatId: 'chat-1',
      now: noon,
    );

    expect(decision.playSound, isFalse);
    expect(decision.vibrate, isTrue);
  });

  test('previews off is reported even when everything else is on', () {
    final decision = useCase.execute(
      preferences: const NotificationPreferences(showPreview: false),
      chatId: 'chat-1',
      now: noon,
    );

    expect(decision.show, isTrue);
    expect(decision.showPreview, isFalse);
  });
}
