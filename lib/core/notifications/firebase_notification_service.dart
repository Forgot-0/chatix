import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:chatix/core/notifications/local_notification_presenter.dart';
import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/core/utils/logger.dart';

/// Push, as it arrives from Firebase, and the shade, as this app writes to it.
///
/// Deliberately does not decide anything: a foreground message is put on
/// [notificationStream] and it is the notification feature that consults the
/// reader's settings and draws it, because those settings are local and this
/// class has no business knowing about them.
class FirebaseNotificationService implements NotificationService {
  FirebaseNotificationService({
    LocalNotificationPresenter? presenter,
    Future<NotificationActionLabels> Function()? labelsLoader,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
    Future<void> Function(RemoteMessage message)? onBackgroundMessage,
  }) : _local = presenter ?? LocalNotificationPresenter(),
       _labelsLoader =
           labelsLoader ?? (() async => const NotificationActionLabels()),
       _onBackgroundResponse = onBackgroundResponse,
       _onBackgroundMessage = onBackgroundMessage;

  final LocalNotificationPresenter _local;
  final Future<NotificationActionLabels> Function() _labelsLoader;
  final DidReceiveBackgroundNotificationResponseCallback?
  _onBackgroundResponse;
  final Future<void> Function(RemoteMessage message)? _onBackgroundMessage;

  final StreamController<NotificationMessage> _messages =
      StreamController<NotificationMessage>.broadcast();
  final StreamController<NotificationMessage> _taps =
      StreamController<NotificationMessage>.broadcast();
  final StreamController<NotificationActionEvent> _actions =
      StreamController<NotificationActionEvent>.broadcast();
  final StreamController<String> _tokens = StreamController<String>.broadcast();

  bool _available = false;

  bool get isAvailable => _available;

  /// The presenter, for callers that draw notifications themselves.
  LocalNotificationPresenter get presenter => _local;

  @override
  Future<void> init() async {
    // The shade works whether or not Firebase does — a build without
    // `google-services.json` still shows what the socket brings in. It is also
    // the half most likely to be missing on a given platform, so a failure
    // here must not stop push from being set up, and must never escape: this
    // runs unawaited from a provider, where a thrown error has nowhere to go.
    try {
      await configureChannels();
    } catch (error, stackTrace) {
      Logger.error('Local notifications are unavailable', error, stackTrace);
    }

    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (error) {
      Logger.warning(
        'Push disabled — Firebase is not configured for this build ($error)',
      );
      _available = false;
      return;
    }

    final backgroundMessage = _onBackgroundMessage;
    if (backgroundMessage != null) {
      FirebaseMessaging.onBackgroundMessage(backgroundMessage);
    }

    FirebaseMessaging.onMessage.listen(
      (message) => _messages.add(_toMessage(message, foreground: true)),
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _taps.add(_toMessage(message, foreground: false)),
    );

    FirebaseMessaging.instance.onTokenRefresh.listen(_tokens.add);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _taps.add(_toMessage(initial, foreground: false));
    }
  }

  @override
  Future<void> configureChannels() async {
    final labels = await _labelsLoader();

    await _local.initialize(
      replyLabel: labels.reply,
      replyPlaceholder: labels.replyPlaceholder,
      markReadLabel: labels.markRead,
      onResponse: _onResponse,
      onBackgroundResponse: _onBackgroundResponse,
    );

    _local.setActionLabels(
      replyLabel: labels.reply,
      replyPlaceholder: labels.replyPlaceholder,
      markReadLabel: labels.markRead,
    );
  }

  void _onResponse(NotificationResponse response) {
    final payload = decodeNotificationPayload(response.payload);
    final action = NotificationActionType.fromId(response.actionId);

    final event = NotificationActionEvent(
      notificationId: '${response.id ?? ''}',
      payload: payload,
      action: action,
      replyText: response.input,
    );

    _actions.add(event);

    // A tap on the body itself is a request to open the app at what the
    // notification was about; a button press is not.
    if (action == null) {
      _taps.add(
        NotificationMessage(
          id: event.notificationId,
          data: payload,
          foreground: false,
        ),
      );
    }
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    if (!_available) return NotificationPermissionStatus.denied;

    final settings = await FirebaseMessaging.instance.requestPermission();
    return _statusOf(settings.authorizationStatus);
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async {
    if (!_available) return NotificationPermissionStatus.denied;

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return _statusOf(settings.authorizationStatus);
  }

  @override
  Future<String?> getToken() async {
    if (!_available) return null;

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await FirebaseMessaging.instance.getAPNSToken();
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (error) {
      Logger.warning('Push token unavailable ($error)');
      return null;
    }
  }

  @override
  Stream<String> get tokenRefreshStream => _tokens.stream;

  @override
  Future<void> handleBackgroundMessage(Map<String, dynamic> message) async {
    _messages.add(
      NotificationMessage(
        id: '${message['messageId'] ?? DateTime.now().millisecondsSinceEpoch}',
        title: message['title'] as String?,
        body: message['body'] as String?,
        data: message,
        foreground: false,
      ),
    );
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    if (_available) await FirebaseMessaging.instance.subscribeToTopic(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_available) {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    }
  }

  @override
  Future<void> showLocalNotification({
    required String id,
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
    String? action,
    String? channel,
  }) {
    return show(
      LocalNotificationRequest(
        id: id,
        title: title,
        body: body,
        payload: data ?? const <String, dynamic>{},
        channel: channel ?? LocalNotificationPresenter.chatChannelId,
      ),
    );
  }

  @override
  Future<void> show(LocalNotificationRequest request) => _local.show(request);

  @override
  Future<void> clearNotification(String id) => _local.cancel(id);

  @override
  Future<void> cancelGroup(String groupKey) => _local.cancelGroup(groupKey);

  @override
  Future<void> clearAllNotifications() => _local.cancelAll();

  @override
  Stream<NotificationMessage> get notificationStream => _messages.stream;

  @override
  Stream<NotificationMessage> get notificationTapStream => _taps.stream;

  @override
  Stream<NotificationActionEvent> get actionStream => _actions.stream;

  static NotificationMessage _toMessage(
    RemoteMessage message, {
    required bool foreground,
  }) {
    final notification = message.notification;

    // The two halves arrive separately — a `notification` block the platform
    // may have drawn itself and a free-form `data` map — and everything
    // downstream reads one payload, so they are merged here.
    final data = <String, dynamic>{
      ...message.data,
      if (notification?.title != null) 'title': notification!.title,
      if (notification?.body != null) 'body': notification!.body,
    };

    return NotificationMessage(
      id: message.messageId ?? '${message.hashCode}',
      title: notification?.title,
      body: notification?.body,
      data: data,
      channel: data['chat_id'] != null
          ? LocalNotificationPresenter.chatChannelId
          : LocalNotificationPresenter.systemChannelId,
      foreground: foreground,
    );
  }

  static NotificationPermissionStatus _statusOf(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return NotificationPermissionStatus.authorized;
      case AuthorizationStatus.provisional:
        return NotificationPermissionStatus.provisional;
      case AuthorizationStatus.denied:
        return NotificationPermissionStatus.denied;
      case AuthorizationStatus.notDetermined:
        return NotificationPermissionStatus.notDetermined;
      case AuthorizationStatus.deniedPermanently:
        return NotificationPermissionStatus.denied;
    }
  }
}
