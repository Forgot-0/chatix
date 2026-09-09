import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/core/utils/logger.dart';

class FirebaseNotificationService implements NotificationService {
  FirebaseNotificationService({FlutterLocalNotificationsPlugin? local})
    : _local = local ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _local;

  final StreamController<NotificationMessage> _messages =
      StreamController<NotificationMessage>.broadcast();
  final StreamController<NotificationMessage> _taps =
      StreamController<NotificationMessage>.broadcast();

  bool _available = false;

  bool get isAvailable => _available;

  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
        'chat_messages',
        'Messages',
        description: 'New messages in your chats',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _systemChannel =
      AndroidNotificationChannel(
        'system',
        'System',
        description: 'Account and service notices',
        importance: Importance.defaultImportance,
      );

  @override
  Future<void> init() async {
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

    await configureChannels();

    FirebaseMessaging.onMessage.listen((message) {
      _messages.add(_toMessage(message, foreground: true));
      final notification = message.notification;
      if (notification != null) {
        unawaited(
          showLocalNotification(
            id: message.messageId ?? '${message.hashCode}',
            title: notification.title ?? '',
            body: notification.body ?? '',
            data: message.data,
            channel: _channelFor(message.data),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _taps.add(_toMessage(message, foreground: false)),
    );

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _taps.add(_toMessage(initial, foreground: false));
    }
  }

  @override
  Future<void> configureChannels() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        _taps.add(NotificationMessage(id: payload, foreground: false));
      },
    );

    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_chatChannel);
    await android?.createNotificationChannel(_systemChannel);
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
  }) async {
    final resolved = channel == 'system' ? _systemChannel : _chatChannel;

    await _local.show(
      id: id.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          resolved.id,
          resolved.name,
          channelDescription: resolved.description,
          importance: resolved.importance,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: id,
    );
  }

  @override
  Future<void> clearNotification(String id) => _local.cancel(id: id.hashCode);

  @override
  Future<void> clearAllNotifications() => _local.cancelAll();

  @override
  Stream<NotificationMessage> get notificationStream => _messages.stream;

  @override
  Stream<NotificationMessage> get notificationTapStream => _taps.stream;

  static String _channelFor(Map<String, dynamic> data) =>
      data['chat_id'] != null ? 'chat_messages' : 'system';

  static NotificationMessage _toMessage(
    RemoteMessage message, {
    required bool foreground,
  }) {
    final notification = message.notification;
    return NotificationMessage(
      id: message.messageId ?? '${message.hashCode}',
      title: notification?.title,
      body: notification?.body,
      data: message.data,
      channel: _channelFor(message.data),
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
