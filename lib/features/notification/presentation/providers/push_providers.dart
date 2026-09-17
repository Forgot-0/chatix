import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/notifications/notification_providers.dart';
import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/core/router/app_router.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:chatix/features/notification/data/background_notification_handler.dart';
import 'package:chatix/features/notification/data/datasources/notification_avatar_cache.dart';
import 'package:chatix/features/notification/data/notification_action_executor.dart';
import 'package:chatix/features/notification/data/notification_copy.dart';
import 'package:chatix/features/notification/data/push_notification_presenter.dart';
import 'package:chatix/features/notification/domain/entities/device_platform.dart';
import 'package:chatix/features/notification/domain/entities/push_message.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/features/notification/presentation/providers/notification_preferences_provider.dart';
import 'package:chatix/features/notification/presentation/providers/notification_providers.dart';
import 'package:chatix/features/notification/presentation/utils/notification_route_resolver.dart';

/// What `main()` hands to the core notification service.
///
/// The two functions are top-level and `vm:entry-point` because the platform
/// calls them on isolates this app never started.
NotificationServiceHooks notificationServiceHooks() =>
    NotificationServiceHooks(
      labelsLoader: () async {
        final copy = await loadPushCopy();
        return NotificationActionLabels(
          reply: copy.replyLabel,
          replyPlaceholder: copy.replyPlaceholder,
          markRead: copy.markReadLabel,
        );
      },
      onBackgroundResponse: onBackgroundNotificationResponse,
      onBackgroundMessage: onBackgroundPushMessage,
    );

/// Which of `IOS`/`WEB`/`ANDROID` this build is (api-docs §7.1 knows no
/// others), or `null` on a desktop build that `POST /devices/` has no value
/// for — registration is skipped there rather than guessed at.
final devicePlatformProvider = Provider<DevicePlatform?>(
  (ref) => DevicePlatform.current,
);

final notificationAvatarCacheProvider = Provider<NotificationAvatarCache>((ref) {
  return NotificationAvatarCache();
});

final pushNotificationPresenterProvider = Provider<PushNotificationPresenter>((
  ref,
) {
  return PushNotificationPresenter(
    notifications: ref.watch(notificationServiceProvider),
    avatars: ref.watch(notificationAvatarCacheProvider),
  );
});

final notificationActionExecutorProvider = Provider<NotificationActionExecutor>(
  (ref) => NotificationActionExecutor(ref.watch(chatRestDataSourceProvider)),
);

/// Registers this device for push, and keeps it registered.
///
/// `POST /devices/` (api-docs §7.1) is not a one-off: the platform rotates the
/// token on its own schedule, and a device that does not re-register simply
/// stops receiving anything, silently. The state is the token last accepted by
/// the server, which is also what keeps a rebuild from re-posting it.
class PushRegistrationController extends Notifier<String?> {
  @override
  String? build() {
    if (!ref.watch(authProvider).isAuthenticated) return null;

    final service = ref.watch(notificationServiceProvider);
    final subscription = service.tokenRefreshStream.listen(_register);
    ref.onDispose(subscription.cancel);

    scheduleMicrotask(registerCurrentToken);

    return stateOrNull;
  }

  /// Asks for the grant if it has never been asked for, then registers.
  ///
  /// A denial is not retried: Android 13+ and iOS both stop showing the prompt
  /// after one refusal, so asking again only costs a round trip.
  Future<void> registerCurrentToken() async {
    final service = ref.read(notificationServiceProvider);

    var status = await service.getPermissionStatus();
    if (status == NotificationPermissionStatus.notDetermined) {
      status = await service.requestPermission();
    }
    if (status == NotificationPermissionStatus.denied) return;

    final token = await service.getToken();
    if (token == null || token.isEmpty) return;

    await _register(token);
  }

  Future<void> _register(String token) async {
    if (token == state) return;

    final platform = ref.read(devicePlatformProvider);
    if (platform == null) return;

    final result = await ref
        .read(registerDeviceUseCaseProvider)
        .execute(
          token: token,
          platform: platform,
          deviceName: AppConstants.appName,
        );

    if (!ref.mounted) return;

    result.match(
      (failure) => Logger.warning('Device not registered: ${failure.message}'),
      (_) => state = token,
    );
  }
}

final pushRegistrationProvider =
    NotifierProvider<PushRegistrationController, String?>(
      PushRegistrationController.new,
    );

/// Draws pushes that arrive while the app is open.
///
/// The platform draws nothing for a foreground message, which is exactly what
/// this app wants: the reader's own settings — quiet hours, per-chat profile,
/// whether the text may be shown — only exist locally, so the notification has
/// to be assembled here to honour them.
final foregroundPushProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);

  final subscription = service.notificationStream.listen((notification) async {
    final data = notification.data;
    if (data == null || data.isEmpty) return;

    final message = PushMessage.fromPayload(data);

    final shown = await ref
        .read(pushNotificationPresenterProvider)
        .present(
          message,
          preferences: ref.read(notificationPreferencesProvider),
          copy: await loadPushCopy(),
        );

    if (shown) {
      unawaited(ref.read(notificationBadgeProvider.notifier).refresh());
    }
  });

  ref.onDispose(subscription.cancel);
});

/// Carries out notification buttons pressed while the app is running.
final notificationActionProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);

  final subscription = service.actionStream.listen((event) async {
    if (event.action == null) return;

    final result = await ref
        .read(notificationActionExecutorProvider)
        .execute(event);

    result.match(
      (failure) => Logger.warning(
        'Notification action ${event.action?.id} failed: ${failure.message}',
      ),
      (_) {
        final chatId = PushMessage.fromPayload(event.payload).chatId;
        if (chatId != null) {
          unawaited(service.cancelGroup('chat_$chatId'));
        }
        unawaited(ref.read(notificationBadgeProvider.notifier).refresh());
      },
    );
  });

  ref.onDispose(subscription.cancel);
});

/// Opens what a tapped notification was about.
///
/// The payload is untyped (api-docs §7.2), so a tap that cannot be resolved to
/// a message still opens the chat, and one that cannot be resolved to a chat
/// opens the notifications list rather than doing nothing.
final notificationTapProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);

  final subscription = service.notificationTapStream.listen((notification) {
    final data = notification.data;
    final route = data == null
        ? null
        : resolveNotificationRouteFromPayload(data);

    ref.read(routerProvider).push(route ?? NotificationsRoute.location);
  });

  ref.onDispose(subscription.cancel);
});

/// Everything push-related that has to be running while the app is.
///
/// Watched once, above the router, the way the socket's lifecycle is.
final pushLifecycleProvider = Provider<void>((ref) {
  // Deliberately does NOT reach for `notificationBadgeProvider`. The badge is
  // owned by `AppShell`, which is mounted for the whole authenticated tree and
  // resyncs it on resume; starting it from here instead put `GET
  // /notifications/unread_count/` in the same microtask as the auth state
  // flipping, and a 401 or 403 from it lands on the session-expiry path —
  // signing the user out of the login they just completed.
  ref.watch(pushRegistrationProvider);
  ref.watch(foregroundPushProvider);
  ref.watch(notificationActionProvider);
  ref.watch(notificationTapProvider);
});
