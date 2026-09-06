import 'dart:async';

class NotificationMessage {
  final String id;

  final String? title;

  final String? body;

  final String? imageUrl;

  final Map<String, dynamic>? data;

  final String? action;

  final String? channel;

  final bool foreground;

  const NotificationMessage({
    required this.id,
    this.title,
    this.body,
    this.imageUrl,
    this.data,
    this.action,
    this.channel,
    this.foreground = true,
  });

  @override
  String toString() {
    return 'NotificationMessage{'
        'id: $id, '
        'title: $title, '
        'body: $body, '
        'imageUrl: $imageUrl, '
        'data: $data, '
        'action: $action, '
        'channel: $channel, '
        'foreground: $foreground'
        '}';
  }
}

enum NotificationPermissionStatus {
  notDetermined,
  denied,
  authorized,
  provisional,
}

abstract class NotificationService {
  Future<void> init();

  Future<NotificationPermissionStatus> requestPermission();

  Future<NotificationPermissionStatus> getPermissionStatus();

  Future<String?> getToken();

  Future<void> handleBackgroundMessage(Map<String, dynamic> message);

  Future<void> configureChannels();

  Future<void> subscribeToTopic(String topic);

  Future<void> unsubscribeFromTopic(String topic);

  Future<void> showLocalNotification({
    required String id,
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
    String? action,
    String? channel,
  });

  Future<void> clearNotification(String id);

  Future<void> clearAllNotifications();

  Stream<NotificationMessage> get notificationStream;

  Stream<NotificationMessage> get notificationTapStream;
}
