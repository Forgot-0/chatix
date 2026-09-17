import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/analytics/analytics_providers.dart';
import 'package:chatix/core/notifications/debug_notification_service.dart';
import 'package:chatix/core/notifications/firebase_notification_service.dart';
import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/core/utils/logger.dart';

const bool useDebugNotifications = bool.fromEnvironment(
  'CHATIX_DEBUG_NOTIFICATIONS',
);

/// The parts of push handling that only the app can supply.
///
/// Drawing a push and answering a reply typed into the shade both need to know
/// about chats, about the reader's local notification settings and about the
/// ARB catalogue — none of which belongs in `core`. So the notification
/// feature writes those functions and `main()` hands them down, the same way
/// it hands down the cookie jar.
class NotificationServiceHooks {
  const NotificationServiceHooks({
    this.labelsLoader,
    this.onBackgroundResponse,
    this.onBackgroundMessage,
  });

  /// Resolves the action-button captions in the reader's language.
  final Future<NotificationActionLabels> Function()? labelsLoader;

  /// Runs on a background isolate when a notification button is pressed while
  /// the app is not running. Must be a top-level `vm:entry-point` function.
  final DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse;

  /// Runs on a background isolate for a push that arrives while the app is not
  /// in the foreground. Must be a top-level `vm:entry-point` function.
  final Future<void> Function(RemoteMessage message)? onBackgroundMessage;
}

final notificationServiceHooksProvider = Provider<NotificationServiceHooks>(
  (ref) => const NotificationServiceHooks(),
);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final hooks = ref.watch(notificationServiceHooksProvider);

  final NotificationService service = useDebugNotifications
      ? DebugNotificationService()
      : FirebaseNotificationService(
          labelsLoader: hooks.labelsLoader,
          onBackgroundResponse: hooks.onBackgroundResponse,
          onBackgroundMessage: hooks.onBackgroundMessage,
        );

  final analytics = ref.watch(analyticsProvider);

  service.notificationStream.listen((notification) {
    analytics.logUserAction(
      action: 'notification_received',
      category: 'notification',
      label: notification.channel ?? 'default',
      parameters: {
        'notification_id': notification.id,
        'title': notification.title,
        'foreground': notification.foreground,
      },
    );
  });

  service.notificationTapStream.listen((notification) {
    analytics.logUserAction(
      action: 'notification_tapped',
      category: 'notification',
      label: notification.channel ?? 'default',
      parameters: {
        'notification_id': notification.id,
        'action': notification.action,
      },
    );
  });

  // Fire-and-forget, but not silently: whatever goes wrong setting push up,
  // the app around it carries on, and the reason is in the log rather than in
  // an unhandled asynchronous error.
  unawaited(
    Future(service.init).catchError(
      (Object error, StackTrace stackTrace) =>
          Logger.error('Push could not be set up', error, stackTrace),
    ),
  );

  ref.onDispose(() {
    if (service is DebugNotificationService) service.dispose();
  });

  return service;
});

final notificationsEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  final status = await service.getPermissionStatus();
  return status == NotificationPermissionStatus.authorized ||
      status == NotificationPermissionStatus.provisional;
});
