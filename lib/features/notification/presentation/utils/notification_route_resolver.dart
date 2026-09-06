import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/notification/domain/entities/notification_entity.dart';

String? resolveNotificationRoute(NotificationEntity notification) {
  final chatId = notification.chatId;
  if (chatId != null) {
    return ChatDetailRoute(chatId).location;
  }

  return null;
}

bool hasNotificationDestination(NotificationEntity notification) =>
    resolveNotificationRoute(notification) != null;
