import 'package:equatable/equatable.dart';

import 'package:chatix/features/notification/domain/entities/notification_preferences.dart';

/// What the app is about to do with one incoming notification.
class NotificationDisplayDecision extends Equatable {
  const NotificationDisplayDecision({
    required this.show,
    required this.playSound,
    required this.vibrate,
    required this.showPreview,
  });

  /// Nothing is drawn at all — the chat's profile ruled it out.
  const NotificationDisplayDecision.suppressed()
    : show = false,
      playSound = false,
      vibrate = false,
      showPreview = false;

  final bool show;

  final bool playSound;

  final bool vibrate;

  /// Whether the body may carry the message text, or only who sent it.
  final bool showPreview;

  @override
  List<Object?> get props => [show, playSound, vibrate, showPreview];
}

/// Turns the reader's settings into a decision about one notification.
///
/// All of the notification settings are local (api-docs §7 has no endpoint for
/// any of them), so this is the only place they take effect — which is also
/// why it is a pure function of its inputs and has no dependencies: the same
/// call has to be answerable from the background isolate a push wakes up.
class ResolveNotificationDisplayUseCase {
  const ResolveNotificationDisplayUseCase();

  NotificationDisplayDecision execute({
    required NotificationPreferences preferences,
    String? chatId,
    bool isMention = false,
    bool isSystem = false,
    DateTime? now,
  }) {
    if (!isSystem) {
      switch (preferences.profileFor(chatId)) {
        case ChatNotificationProfile.off:
          return const NotificationDisplayDecision.suppressed();
        case ChatNotificationProfile.mentionsOnly:
          if (!isMention) {
            return const NotificationDisplayDecision.suppressed();
          }
        case ChatNotificationProfile.all:
          break;
      }
    }

    // Quiet hours silence rather than swallow: a message that arrived at
    // three in the morning is still there in the morning, which is what
    // people expect of a "do not disturb" and not of a filter.
    final quiet = preferences.quietHours.isActiveAt(now ?? DateTime.now());

    return NotificationDisplayDecision(
      show: true,
      playSound: preferences.sound && !quiet,
      vibrate: preferences.vibration && !quiet,
      showPreview: preferences.showPreview,
    );
  }
}
