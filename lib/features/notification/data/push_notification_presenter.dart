import 'dart:collection';

import 'package:chatix/core/notifications/local_notification_presenter.dart';
import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/features/notification/data/datasources/notification_avatar_cache.dart';
import 'package:chatix/features/notification/domain/entities/notification_preferences.dart';
import 'package:chatix/features/notification/domain/entities/push_message.dart';
import 'package:chatix/features/notification/domain/usecases/resolve_notification_display_use_case.dart';

/// The wording a notification needs, resolved once by whoever has a locale.
///
/// Passed in rather than read from a delegate inside the presenter because
/// the background isolate that draws a push has no `BuildContext` to read one
/// from — it loads the same ARB strings by hand.
class PushNotificationCopy {
  const PushNotificationCopy({
    required this.appName,
    required this.newMessage,
    required this.replyLabel,
    required this.replyPlaceholder,
    required this.markReadLabel,
  });

  final String appName;

  /// The body used both for a push that carried no text — an attachment, say
  /// — and for one whose text the reader has asked not to show on the lock
  /// screen.
  final String newMessage;

  final String replyLabel;
  final String replyPlaceholder;
  final String markReadLabel;
}

/// Turns a push into what the reader actually sees.
///
/// Everything the settings decide happens here — whether to draw at all,
/// whether it makes a sound, whether the text is shown — because this is the
/// last point both the foreground app and the background isolate pass through.
class PushNotificationPresenter {
  PushNotificationPresenter({
    required NotificationSink notifications,
    required NotificationAvatarCache avatars,
    ResolveNotificationDisplayUseCase decisions =
        const ResolveNotificationDisplayUseCase(),
  }) : _notifications = notifications,
       _avatars = avatars,
       _decisions = decisions;

  final NotificationSink _notifications;
  final NotificationAvatarCache _avatars;
  final ResolveNotificationDisplayUseCase _decisions;

  /// Push is at-least-once, exactly like the socket (api-docs §6), so the same
  /// message can arrive twice; `payload.event_id` is what tells them apart.
  final LinkedHashSet<String> _seenEvents = LinkedHashSet<String>();

  static const int _maxRememberedEvents = 200;

  /// Draws [message] if the settings allow it. Returns whether anything was
  /// posted, which is what the caller needs to know before touching a badge.
  Future<bool> present(
    PushMessage message, {
    required NotificationPreferences preferences,
    required PushNotificationCopy copy,
    DateTime? now,
  }) async {
    if (!message.isActionable) return false;
    if (!_remember(message)) return false;

    final decision = _decisions.execute(
      preferences: preferences,
      chatId: message.chatId,
      isMention: message.isMention,
      isSystem: message.isSystem,
      now: now,
    );
    if (!decision.show) return false;

    final isChat = message.chatId != null;

    final title =
        (decision.showPreview ? message.senderName : null) ??
        message.chatName ??
        message.title ??
        copy.appName;

    final body = decision.showPreview
        ? (message.text ?? copy.newMessage)
        : copy.newMessage;

    // Only worth fetching when it can be drawn and when the reader has not
    // asked for the sender to stay off the lock screen.
    final avatarPath = decision.showPreview
        ? await _avatars.fileFor(message.senderAvatarUrl)
        : null;

    await _notifications.show(
      LocalNotificationRequest(
        id: message.notificationId,
        title: title,
        body: body,
        groupKey: message.groupKey,
        // The chat name only earns the subtitle line when it is not already
        // the title — a direct chat titles itself with the person's name.
        subText: message.chatName != null && message.chatName != title
            ? message.chatName
            : null,
        largeIconPath: avatarPath,
        payload: message.raw,
        channel: isChat
            ? LocalNotificationPresenter.chatChannelId
            : LocalNotificationPresenter.systemChannelId,
        playSound: decision.playSound,
        enableVibration: decision.vibrate,
        // Replying to a system notice would have nowhere to send the text,
        // and marking one read is what the notifications screen is for.
        actions: isChat && _canActOn(message)
            ? const {
                NotificationActionType.reply,
                NotificationActionType.markRead,
              }
            : const <NotificationActionType>{},
        when: message.sentAt,
      ),
    );

    return true;
  }

  /// Marking read needs a `seq` to send (api-docs §5.4); replying needs only
  /// the chat. A message with neither still shows, just without buttons.
  bool _canActOn(PushMessage message) => message.chatId != null;

  bool _remember(PushMessage message) {
    final eventId = message.eventId;
    if (eventId == null) return true;

    if (!_seenEvents.add(eventId)) return false;
    if (_seenEvents.length > _maxRememberedEvents) {
      _seenEvents.remove(_seenEvents.first);
    }
    return true;
  }
}
