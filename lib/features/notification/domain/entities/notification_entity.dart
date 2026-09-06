import 'package:equatable/equatable.dart';

enum NotificationType {
  system,
  chat;

  String get wire => name;

  static NotificationType fromWire(String? value) {
    return NotificationType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => NotificationType.system,
    );
  }
}

class NotificationEntity extends Equatable {
  final int id;
  final int userId;
  final NotificationType type;
  final String title;

  final String? message;

  final Map<String, dynamic> payload;

  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.payload,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
  });

  NotificationEntity copyWith({bool? isRead}) {
    return NotificationEntity(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      payload: payload,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String? get chatId => _stringValue('chat_id');

  String? get messageId => _stringValue('message_id');

  String? _stringValue(String key) {
    final value = payload[key];
    if (value == null) return null;
    final asString = value.toString().trim();
    return asString.isEmpty ? null : asString;
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    type,
    title,
    message,
    payload,
    isRead,
    createdAt,
    updatedAt,
  ];
}
