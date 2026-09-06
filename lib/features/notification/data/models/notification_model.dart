import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:chatix/features/notification/domain/entities/notification_entity.dart';

part 'notification_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class NotificationModel extends Equatable {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String? message;

  @JsonKey(defaultValue: <String, dynamic>{})
  final Map<String, dynamic> payload;

  final bool isRead;
  final String createdAt;
  final String updatedAt;

  const NotificationModel({
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

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationModelToJson(this);
}

extension NotificationModelX on NotificationModel {
  NotificationEntity toEntity() {
    return NotificationEntity(
      id: id,
      userId: userId,
      type: NotificationType.fromWire(type),
      title: title,
      message: message,
      payload: payload,
      isRead: isRead,
      createdAt: DateTime.tryParse(createdAt)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(updatedAt)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
