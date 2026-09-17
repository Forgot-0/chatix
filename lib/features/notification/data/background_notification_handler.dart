import 'dart:ui' show DartPluginRegistrant;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/network/interceptors/auth_interceptor.dart';
import 'package:chatix/core/network/interceptors/set_cookie_compat_interceptor.dart';
import 'package:chatix/core/network/interceptors/trailing_slash_interceptor.dart';
import 'package:chatix/core/notifications/local_notification_presenter.dart';
import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/core/storage/secure_storage_service.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:chatix/features/notification/data/datasources/notification_avatar_cache.dart';
import 'package:chatix/features/notification/data/datasources/notification_preferences_store.dart';
import 'package:chatix/features/notification/data/notification_action_executor.dart';
import 'package:chatix/features/notification/data/notification_copy.dart';
import 'package:chatix/features/notification/data/push_notification_presenter.dart';
import 'package:chatix/features/notification/domain/entities/push_message.dart';

/// What runs when the app itself is not running.
///
/// Two entry points, both invoked by the platform on an isolate of its own
/// with no provider graph, no widget tree and nothing this app's `main()` set
/// up: a push arriving while the app is closed, and a reply typed into the
/// shade. Everything either one needs is rebuilt here from scratch — which is
/// why both the notification drawing and the HTTP stack are written as plain
/// classes that take their dependencies rather than as providers.
///
/// Both must be top-level and annotated `vm:entry-point`, or the compiler
/// drops them from a release build and the buttons silently do nothing.
@pragma('vm:entry-point')
Future<void> onBackgroundPushMessage(RemoteMessage message) async {
  await _ensureIsolateReady();

  try {
    await Firebase.initializeApp();
  } on Object catch (error) {
    Logger.warning('Background push ignored — no Firebase ($error)');
    return;
  }

  final payload = <String, dynamic>{
    ...message.data,
    if (message.notification?.title != null)
      'title': message.notification!.title,
    if (message.notification?.body != null) 'body': message.notification!.body,
  };

  await presentPushInBackground(payload);
}

/// Draws a push from an isolate that has nothing set up.
///
/// Split out of [onBackgroundPushMessage] so the same path can be exercised
/// without a `RemoteMessage` to hand.
Future<void> presentPushInBackground(Map<String, dynamic> payload) async {
  try {
    final copy = await loadPushCopy();
    final notifications = await _readyPresenter(copy);

    final presenter = PushNotificationPresenter(
      notifications: notifications,
      avatars: NotificationAvatarCache(),
    );

    await presenter.present(
      PushMessage.fromPayload(payload),
      preferences: await NotificationPreferencesStore.loadStandalone(),
      copy: copy,
    );
  } on Object catch (error, stackTrace) {
    Logger.error('Background push could not be drawn', error, stackTrace);
  }
}

/// A presenter this isolate may actually draw with.
///
/// The plugin is a singleton, but `initialize` is per-isolate: without it the
/// channels do not exist here and a `show` or `cancel` goes nowhere.
Future<LocalNotificationPresenter> _readyPresenter(
  PushNotificationCopy copy,
) async {
  final presenter = LocalNotificationPresenter();

  await presenter.initialize(
    replyLabel: copy.replyLabel,
    replyPlaceholder: copy.replyPlaceholder,
    markReadLabel: copy.markReadLabel,
    onBackgroundResponse: onBackgroundNotificationResponse,
  );

  return presenter;
}

/// A notification button pressed while the app is not running.
///
/// Answers the press for real rather than queueing it: a reply that only
/// leaves the device the next time the app is opened is not a reply.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationResponse(
  NotificationResponse response,
) async {
  await _ensureIsolateReady();

  final action = NotificationActionType.fromId(response.actionId);
  if (action == null) return;

  final event = NotificationActionEvent(
    notificationId: '${response.id ?? ''}',
    payload: decodeNotificationPayload(response.payload),
    action: action,
    replyText: response.input,
  );

  try {
    final api = await buildBackgroundApiClient();
    final result = await NotificationActionExecutor(
      ChatRestDataSourceImpl(api),
    ).execute(event);

    await result.match(
      (failure) => _reportActionFailure(event, failure.message),
      (_) async {
        final chatId = PushMessage.fromPayload(event.payload).chatId;
        if (chatId == null) return;

        final presenter = await _readyPresenter(await loadPushCopy());
        await presenter.cancelGroup('chat_$chatId');
      },
    );
  } on Object catch (error, stackTrace) {
    Logger.error('Notification action failed', error, stackTrace);
    await _reportActionFailure(event, '$error');
  }
}

/// Says so in the shade when an action could not be carried out.
///
/// Silently swallowing a reply is the one outcome worth avoiding: the reader
/// has no other way to find out it never left the device.
Future<void> _reportActionFailure(
  NotificationActionEvent event,
  String reason,
) async {
  try {
    final l10n = await loadNotificationLocalizations();
    final notifications = await _readyPresenter(pushCopyFrom(l10n));

    await notifications.show(
      LocalNotificationRequest(
        id: 'action_failed_${event.notificationId}',
        title: event.action == NotificationActionType.reply
            ? l10n.notificationReplyFailed
            : l10n.notificationActionFailed,
        body: event.replyText ?? reason,
        channel: LocalNotificationPresenter.systemChannelId,
        payload: event.payload,
      ),
    );
  } on Object catch (error) {
    Logger.warning('Could not report the failed notification action ($error)');
  }
}

/// The HTTP stack, rebuilt outside the provider graph.
///
/// Same pieces `dioProvider` assembles — the cookie jar the refresh cookie
/// lives in, the trailing-slash interceptor without which every path 404s
/// (api-docs §0), and the auth interceptor that renews the five-minute access
/// token — so a background call behaves exactly like a foreground one.
Future<ApiClient> buildBackgroundApiClient() async {
  final appDir = await getApplicationDocumentsDirectory();
  final cookieJar = PersistCookieJar(
    storage: FileStorage('${appDir.path}/.cookies/'),
  );
  final secureStorage = SecureStorageServiceImpl.create();

  BaseOptions options() => BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
    receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
    headers: const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  );

  final sideChannel = Dio(options())
    ..interceptors.addAll([
      const SetCookieCompatInterceptor(),
      CookieManager(cookieJar),
      TrailingSlashInterceptor(),
    ]);

  final dio = Dio(options())
    ..interceptors.addAll([
      const SetCookieCompatInterceptor(),
      CookieManager(cookieJar),
      TrailingSlashInterceptor(),
      AuthInterceptor(sideChannel: sideChannel, secureStorage: secureStorage),
    ]);

  return ApiClient(dio);
}

/// Everything a background isolate needs before it can touch a plugin.
Future<void> _ensureIsolateReady() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // `AppConstants.apiBaseUrl` reads it, and this isolate never ran `main()`.
  if (!dotenv.isInitialized) {
    try {
      await dotenv.load(fileName: '.env');
    } on Object catch (error) {
      Logger.warning('Background isolate has no .env ($error)');
    }
  }
}
