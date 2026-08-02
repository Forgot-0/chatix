import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/features/notification/domain/entities/notification_entity.dart';

/// Where tapping [notification] should take the user, or `null` when the
/// payload doesn't say.
///
/// ⚠️ **Best-effort by design.** `payload` is untyped on the backend
/// (api-docs §8.2): there is no contract that a `chat` notification carries a
/// `chat_id`, and nothing stops a future server version from renaming the
/// key. So this function never assumes and never throws — it looks for keys
/// it recognises, and returns `null` if it finds none. A `null` means "just
/// mark it read and stay put", which is a perfectly good outcome for a
/// `system` notification that has nowhere to go.
///
/// ### Resolution order
///
/// Payload keys win over [NotificationEntity.type], and the more specific
/// target wins over the broader one. A `project` notification whose payload
/// happens to carry a `chat_id` is about *that chat* — the `type` field is
/// only a categorisation for grouping and iconography, not a routing
/// instruction, and treating it as one would send the user to a project page
/// with no idea why.
String? resolveNotificationRoute(NotificationEntity notification) {
  final chatId = notification.chatId;
  if (chatId != null) {
    return AppConstants.chatDetailRoute(chatId);
  }

  final projectId = notification.projectId;
  if (projectId != null) {
    return AppConstants.projectDetailRoute(projectId);
  }

  // No recognised target. Deliberately does NOT fall back to a "type
  // homepage" (e.g. the chat list for `type == chat`): dropping the user on a
  // list they must then search is worse than leaving them in the inbox, where
  // the notification they just tapped is still in front of them.
  return null;
}

/// Whether tapping [notification] will navigate anywhere — lets the row
/// render a chevron only when there is somewhere to go.
bool hasNotificationDestination(NotificationEntity notification) =>
    resolveNotificationRoute(notification) != null;
