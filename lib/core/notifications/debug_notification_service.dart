import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:chatix/core/notifications/notification_service.dart';

class DebugNotificationService implements NotificationService {
  final _notificationStreamController =
      StreamController<NotificationMessage>.broadcast();
  final _notificationTapStreamController =
      StreamController<NotificationMessage>.broadcast();
  final _actionStreamController =
      StreamController<NotificationActionEvent>.broadcast();
  final _tokenRefreshController = StreamController<String>.broadcast();

  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notDetermined;

  @override
  Future<void> init() async {
    debugPrint('🔔 Debug notification service initialized');
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    debugPrint('🔔 Requesting notification permission');
    _permissionStatus = NotificationPermissionStatus.authorized;
    return _permissionStatus;
  }

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async {
    return _permissionStatus;
  }

  @override
  Future<String?> getToken() async {
    final token = 'debug-token-${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('🔔 Generated debug token: $token');
    return token;
  }

  @override
  Stream<String> get tokenRefreshStream => _tokenRefreshController.stream;

  @override
  Future<void> handleBackgroundMessage(Map<String, dynamic> message) async {
    debugPrint('🔔 Handling background message: $message');
  }

  @override
  Future<void> configureChannels() async {
    debugPrint('🔔 Configuring notification channels');
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    debugPrint('🔔 Subscribed to topic: $topic');
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    debugPrint('🔔 Unsubscribed from topic: $topic');
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
    debugPrint('🔔 Showing local notification:');
    debugPrint('🔔 ID: $id');
    debugPrint('🔔 Title: $title');
    debugPrint('🔔 Body: $body');
    if (imageUrl != null) debugPrint('🔔 Image: $imageUrl');
    if (data != null) debugPrint('🔔 Data: $data');
    if (action != null) debugPrint('🔔 Action: $action');
    if (channel != null) debugPrint('🔔 Channel: $channel');

    final notification = NotificationMessage(
      id: id,
      title: title,
      body: body,
      imageUrl: imageUrl,
      data: data,
      action: action,
      channel: channel,
      foreground: true,
    );

    _notificationStreamController.add(notification);
  }

  @override
  Future<void> show(LocalNotificationRequest request) async {
    debugPrint(
      '🔔 Showing ${request.channel} notification ${request.id} '
      'in group ${request.groupKey ?? '-'} '
      'with actions ${request.actions.map((a) => a.id).join(',')}',
    );

    _notificationStreamController.add(
      NotificationMessage(
        id: request.id,
        title: request.title,
        body: request.body,
        data: request.payload,
        channel: request.channel,
      ),
    );
  }

  @override
  Future<void> clearNotification(String id) async {
    debugPrint('🔔 Cleared notification: $id');
  }

  @override
  Future<void> cancelGroup(String groupKey) async {
    debugPrint('🔔 Cleared notification group: $groupKey');
  }

  @override
  Future<void> clearAllNotifications() async {
    debugPrint('🔔 Cleared all notifications');
  }

  @override
  Stream<NotificationMessage> get notificationStream =>
      _notificationStreamController.stream;

  @override
  Stream<NotificationMessage> get notificationTapStream =>
      _notificationTapStreamController.stream;

  @override
  Stream<NotificationActionEvent> get actionStream =>
      _actionStreamController.stream;

  void simulateAction(NotificationActionEvent event) {
    _actionStreamController.add(event);
  }

  void simulateTokenRefresh(String token) {
    _tokenRefreshController.add(token);
  }

  void simulateTap(NotificationMessage notification) {
    _notificationTapStreamController.add(notification);
  }

  void dispose() {
    _notificationStreamController.close();
    _notificationTapStreamController.close();
    _actionStreamController.close();
    _tokenRefreshController.close();
  }
}
