import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/notification/domain/entities/notification_entity.dart';
import 'package:chatix/features/notification/domain/entities/push_message.dart';

/// Where tapping a notification should land.
///
/// `NotificationDTO.payload` is untyped (api-docs §7.2), so the chat id, the
/// message id and the per-chat `seq` are all dug out defensively by
/// [PushMessage]. A payload that names a message opens the chat at it; one
/// that names only a chat opens the chat; one that names neither has nowhere
/// to go and says so rather than guessing.
String? resolveNotificationRoute(NotificationEntity notification) =>
    resolveNotificationRouteFromPayload(notification.payload);

String? resolveNotificationRouteFromPayload(Map<String, dynamic> payload) =>
    resolveRouteForPushMessage(PushMessage.fromPayload(payload));

String? resolveRouteForPushMessage(PushMessage message) {
  final chatId = message.chatId;
  if (chatId == null || chatId.isEmpty) return null;

  return ChatDetailRoute(
    chatId,
    messageSeq: message.messageSeq,
    messageId: message.messageId,
  ).location;
}

bool hasNotificationDestination(NotificationEntity notification) =>
    resolveNotificationRoute(notification) != null;
