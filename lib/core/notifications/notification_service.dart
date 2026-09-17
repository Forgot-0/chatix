import 'dart:async';

class NotificationMessage {
  final String id;

  final String? title;

  final String? body;

  final String? imageUrl;

  final Map<String, dynamic>? data;

  final String? action;

  final String? channel;

  final bool foreground;

  const NotificationMessage({
    required this.id,
    this.title,
    this.body,
    this.imageUrl,
    this.data,
    this.action,
    this.channel,
    this.foreground = true,
  });

  @override
  String toString() {
    return 'NotificationMessage{'
        'id: $id, '
        'title: $title, '
        'body: $body, '
        'imageUrl: $imageUrl, '
        'data: $data, '
        'action: $action, '
        'channel: $channel, '
        'foreground: $foreground'
        '}';
  }
}

enum NotificationPermissionStatus {
  notDetermined,
  denied,
  authorized,
  provisional,
}

/// The buttons a chat notification carries in the shade.
///
/// The ids are part of the platform contract: Android hands them back on the
/// intent and iOS on the category action, and a notification posted by an
/// older build can still be sitting in the shade when a newer one reads it —
/// so they are written down once here and never derived from `name`.
enum NotificationActionType {
  /// Direct reply: the platform collects the text and hands it back without
  /// opening the app.
  reply('reply'),

  /// Mark the chat read where it stands.
  markRead('mark_read');

  const NotificationActionType(this.id);

  final String id;

  static NotificationActionType? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final action in NotificationActionType.values) {
      if (action.id == id) return action;
    }
    return null;
  }
}

/// The captions the action buttons carry.
///
/// Resolved by whoever knows the reader's language and handed to the service,
/// which has no localisation delegate of its own — and on iOS has to register
/// them with the system before the first notification is drawn.
class NotificationActionLabels {
  const NotificationActionLabels({
    this.reply = 'Reply',
    this.replyPlaceholder = 'Message',
    this.markRead = 'Mark as read',
  });

  final String reply;
  final String replyPlaceholder;
  final String markRead;
}

/// One notification to post, described in platform-neutral terms.
///
/// [groupKey] is what makes several messages from the same chat collapse into
/// one entry rather than a stack of unrelated ones: everything sharing a key
/// is bundled under a summary that this app posts alongside them.
class LocalNotificationRequest {
  const LocalNotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    this.groupKey,
    this.subText,
    this.largeIconPath,
    this.payload = const <String, dynamic>{},
    this.channel = 'chat_messages',
    this.playSound = true,
    this.enableVibration = true,
    this.actions = const <NotificationActionType>{},
    this.when,
  });

  /// Stable across re-posts of the same message, so an edit replaces rather
  /// than duplicates.
  final String id;

  final String title;

  final String body;

  /// Chats bundle by this; `null` posts a standalone notification.
  final String? groupKey;

  /// The line above the title — the chat name, when the title is a person.
  final String? subText;

  /// A file on disk, not a URL: the platform draws the icon itself and has no
  /// network of its own.
  final String? largeIconPath;

  /// Travels with the notification and comes back on tap or action.
  final Map<String, dynamic> payload;

  final String channel;

  final bool playSound;

  final bool enableVibration;

  final Set<NotificationActionType> actions;

  final DateTime? when;
}

/// A tap on a notification, or on one of its buttons.
class NotificationActionEvent {
  const NotificationActionEvent({
    required this.notificationId,
    required this.payload,
    this.action,
    this.replyText,
  });

  final String notificationId;

  /// The payload the notification was posted with, decoded.
  final Map<String, dynamic> payload;

  /// `null` when the body itself was tapped rather than a button.
  final NotificationActionType? action;

  /// What the reader typed into the direct-reply field.
  final String? replyText;
}

/// Anything that can put a notification in the shade.
///
/// Two things can: the app's [NotificationService], and the bare
/// [LocalNotificationPresenter] a background isolate builds for itself. Code
/// that draws notifications takes this rather than either of them, so the same
/// code runs in both places.
abstract interface class NotificationSink {
  Future<void> show(LocalNotificationRequest request);
}

abstract class NotificationService implements NotificationSink {
  Future<void> init();

  Future<NotificationPermissionStatus> requestPermission();

  Future<NotificationPermissionStatus> getPermissionStatus();

  Future<String?> getToken();

  /// Fires whenever the platform rotates the push token, which it does on its
  /// own schedule — a device that never re-registers goes quietly silent.
  Stream<String> get tokenRefreshStream;

  Future<void> handleBackgroundMessage(Map<String, dynamic> message);

  Future<void> configureChannels();

  Future<void> subscribeToTopic(String topic);

  Future<void> unsubscribeFromTopic(String topic);

  Future<void> showLocalNotification({
    required String id,
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
    String? action,
    String? channel,
  });

  /// Posts a grouped, actionable notification.
  @override
  Future<void> show(LocalNotificationRequest request);

  Future<void> clearNotification(String id);

  /// Drops every notification bundled under [groupKey], summary included —
  /// what opening the chat should do to the shade.
  Future<void> cancelGroup(String groupKey);

  Future<void> clearAllNotifications();

  Stream<NotificationMessage> get notificationStream;

  Stream<NotificationMessage> get notificationTapStream;

  /// Taps and button presses on notifications this app posted.
  Stream<NotificationActionEvent> get actionStream;
}
