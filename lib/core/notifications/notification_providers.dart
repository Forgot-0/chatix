import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/analytics/analytics_providers.dart';
import 'package:chatix/core/notifications/debug_notification_service.dart';
import 'package:chatix/core/notifications/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = DebugNotificationService();

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

  service.init();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final notificationsEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  final status = await service.getPermissionStatus();
  return status == NotificationPermissionStatus.authorized ||
      status == NotificationPermissionStatus.provisional;
});

class NotificationDeepLinkHandler extends Notifier<String?> {
  @override
  String? build() {
    final service = ref.watch(notificationServiceProvider);

    final sub = service.notificationTapStream.listen(_handleNotificationTap);

    ref.onDispose(sub.cancel);

    return null;
  }

  String? get pendingDeepLink => state;

  void clearPendingDeepLink() {
    state = null;
  }

  void _handleNotificationTap(NotificationMessage notification) {
    if (notification.action != null) {
      state = notification.action;
    }
  }
}

final notificationDeepLinkHandlerProvider =
    NotifierProvider<NotificationDeepLinkHandler, String?>(
      NotificationDeepLinkHandler.new,
    );
