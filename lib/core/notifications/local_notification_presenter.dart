import 'dart:convert';
import 'dart:io' show File, FileSystemException;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:chatix/core/notifications/notification_service.dart';

/// Posts notifications through `flutter_local_notifications`.
///
/// Split out of [NotificationService] because the shade has to be written to
/// from two places that share no state: the app's own isolate, and the
/// background isolate the platform spins up for a push (or for a reply typed
/// straight into the shade) while the app is not running. Both build the same
/// notifications, so both use this.
class LocalNotificationPresenter implements NotificationSink {
  LocalNotificationPresenter({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// The lines each group's summary shows, newest last.
  ///
  /// In-memory on purpose: it is a nicety on top of the bundling Android does
  /// by itself, and the background isolate legitimately starts out not knowing
  /// what is already in the shade.
  final Map<String, List<String>> _groupLines = <String, List<String>>{};

  static const String chatChannelId = 'chat_messages';
  static const String systemChannelId = 'system';

  /// The iOS category that carries the reply and mark-read buttons.
  static const String chatCategoryId = 'chatix_chat_message';

  /// Whether this build has a shade to write to.
  ///
  /// Android, iOS and macOS; everywhere else — Linux, Windows, web — the
  /// plugin would need initialisation settings this app does not have, and
  /// there is no notification surface worth inventing them for.
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static const AndroidNotificationChannel chatChannel =
      AndroidNotificationChannel(
        chatChannelId,
        'Messages',
        description: 'New messages in your chats',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel systemChannel =
      AndroidNotificationChannel(
        systemChannelId,
        'System',
        description: 'Account and service notices',
        importance: Importance.defaultImportance,
      );

  /// How many messages a group's summary lists before it says "and more".
  static const int _maxSummaryLines = 6;

  /// Wires the plugin up and creates the channels.
  ///
  /// [replyLabel] and [markReadLabel] are the button captions; they are passed
  /// in rather than read from a localisation delegate because a background
  /// isolate has no `BuildContext` to read one from.
  Future<void> initialize({
    required String replyLabel,
    required String replyPlaceholder,
    required String markReadLabel,
    DidReceiveNotificationResponseCallback? onResponse,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
  }) async {
    // `initialize` throws unless it is handed settings for the platform it
    // finds itself on, and this app only has a notification story on the three
    // it ships one for. A desktop or web build says so here rather than
    // bringing down everything else push sets up.
    if (!isSupportedPlatform) return;

    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          notificationCategories: [
            DarwinNotificationCategory(
              chatCategoryId,
              actions: [
                DarwinNotificationAction.text(
                  NotificationActionType.reply.id,
                  replyLabel,
                  buttonTitle: replyLabel,
                  placeholder: replyPlaceholder,
                ),
                DarwinNotificationAction.plain(
                  NotificationActionType.markRead.id,
                  markReadLabel,
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(chatChannel);
    await android?.createNotificationChannel(systemChannel);
  }

  /// The button captions, kept so a notification posted later in the same
  /// isolate does not need them passed in again.
  String _replyLabel = 'Reply';
  String _replyPlaceholder = 'Message';
  String _markReadLabel = 'Mark as read';

  /// Re-labels the action buttons, for when the app's language changes.
  void setActionLabels({
    required String replyLabel,
    required String replyPlaceholder,
    required String markReadLabel,
  }) {
    _replyLabel = replyLabel;
    _replyPlaceholder = replyPlaceholder;
    _markReadLabel = markReadLabel;
  }

  @override
  Future<void> show(LocalNotificationRequest request) async {
    if (!isSupportedPlatform) return;

    final channel = request.channel == systemChannelId
        ? systemChannel
        : chatChannel;

    final largeIcon = await _largeIcon(request.largeIconPath);

    await _plugin.show(
      id: stableNotificationId(request.id),
      title: request.title,
      body: request.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
          groupKey: request.groupKey,
          subText: request.subText,
          largeIcon: largeIcon,
          playSound: request.playSound,
          enableVibration: request.enableVibration,
          silent: !request.playSound && !request.enableVibration,
          when: request.when?.millisecondsSinceEpoch,
          category: request.groupKey == null
              ? null
              : AndroidNotificationCategory.message,
          actions: _androidActions(request.actions),
        ),
        iOS: DarwinNotificationDetails(
          presentSound: request.playSound,
          subtitle: request.subText,
          threadIdentifier: request.groupKey,
          categoryIdentifier: request.actions.isEmpty ? null : chatCategoryId,
        ),
      ),
      payload: jsonEncode(request.payload),
    );

    final groupKey = request.groupKey;
    if (groupKey != null) {
      await _showSummary(groupKey, request);
    }
  }

  /// One bundle header per chat, so five messages read as one entry.
  ///
  /// iOS groups by `threadIdentifier` on its own and has no summary to post,
  /// so this is Android-only.
  Future<void> _showSummary(
    String groupKey,
    LocalNotificationRequest request,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final lines = _groupLines.putIfAbsent(groupKey, () => <String>[])
      ..add(request.body);
    if (lines.length > _maxSummaryLines) {
      lines.removeRange(0, lines.length - _maxSummaryLines);
    }

    final title = request.subText ?? request.title;

    await _plugin.show(
      id: stableNotificationId(groupKey),
      title: title,
      body: request.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          chatChannel.id,
          chatChannel.name,
          channelDescription: chatChannel.description,
          importance: chatChannel.importance,
          groupKey: groupKey,
          setAsGroupSummary: true,
          // The children already made the sound; the summary must not make it
          // a second time.
          groupAlertBehavior: GroupAlertBehavior.children,
          playSound: false,
          enableVibration: false,
          styleInformation: InboxStyleInformation(
            List<String>.unmodifiable(lines),
            contentTitle: title,
            summaryText: title,
          ),
        ),
      ),
      payload: jsonEncode(request.payload),
    );
  }

  Future<void> cancel(String id) async {
    if (!isSupportedPlatform) return;
    await _plugin.cancel(id: stableNotificationId(id));
  }

  /// Clears a chat's bundle, summary included — what opening the chat does.
  Future<void> cancelGroup(String groupKey) async {
    _groupLines.remove(groupKey);
    if (!isSupportedPlatform) return;

    final active = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.getActiveNotifications();

    if (active != null) {
      for (final notification in active) {
        if (notification.groupKey == groupKey && notification.id != null) {
          await _plugin.cancel(id: notification.id!);
        }
      }
    }

    await _plugin.cancel(id: stableNotificationId(groupKey));
  }

  Future<void> cancelAll() async {
    _groupLines.clear();
    if (!isSupportedPlatform) return;
    await _plugin.cancelAll();
  }

  List<AndroidNotificationAction> _androidActions(
    Set<NotificationActionType> actions,
  ) {
    return [
      if (actions.contains(NotificationActionType.reply))
        AndroidNotificationAction(
          NotificationActionType.reply.id,
          _replyLabel,
          // Both buttons do their work without a screen, which is the whole
          // point of having them; `showsUserInterface: false` is what routes
          // them to the background isolate instead of launching the app.
          showsUserInterface: false,
          cancelNotification: false,
          inputs: [AndroidNotificationActionInput(label: _replyPlaceholder)],
        ),
      if (actions.contains(NotificationActionType.markRead))
        AndroidNotificationAction(
          NotificationActionType.markRead.id,
          _markReadLabel,
          showsUserInterface: false,
        ),
    ];
  }

  Future<AndroidBitmap<Object>?> _largeIcon(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (defaultTargetPlatform != TargetPlatform.android) return null;

    // The file is a cache entry and may have been evicted between being
    // resolved and being drawn; a missing avatar must not cost the
    // notification.
    try {
      if (!File(path).existsSync()) return null;
    } on FileSystemException {
      return null;
    }

    return FilePathAndroidBitmap(path);
  }
}

/// A notification id that means the same thing in every isolate and every run.
///
/// `String.hashCode` would do for one process, but the shade outlives the
/// process: a reply posted from the background isolate has to be able to
/// cancel a notification the app's own isolate posted. FNV-1a, folded into the
/// positive half of a 32-bit int, which is the range the platforms accept.
int stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit & 0xff;
    hash = (hash * 0x01000193) & 0xffffffff;
    hash ^= (unit >> 8) & 0xff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Decodes the payload a notification was posted with.
///
/// Anything unreadable comes back empty rather than throwing: the payload is
/// written by this app but read by a callback the platform invokes, where a
/// thrown exception is simply a notification that does nothing.
Map<String, dynamic> decodeNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return const <String, dynamic>{};
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
  } on FormatException {
    return const <String, dynamic>{};
  }
}
