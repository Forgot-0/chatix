import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:chatix/features/notification/domain/entities/notification_entity.dart';

part 'notification_model.g.dart';

/// `NotificationDTO` (api-docs §8.2).
///
/// [type] and the two timestamps stay as raw wire strings and are converted
/// in [toEntity], matching the model↔entity boundary the rest of the app uses
/// (cf. `MessageModel`) — parsing failures then surface at one known place
/// instead of inside `fromJson`.
///
/// ⚠️ [payload] is deliberately `Map<String, dynamic>` with a `{}` default.
/// The backend does not type it (api-docs §8.2), so it is carried through
/// verbatim; interpreting it is `NotificationEntity`'s defensive accessors'
/// job. A `null` payload — which the docs don't promise but also don't rule
/// out — becomes an empty map rather than a parse error.
///
/// [message] is nullable per the DTO; [title] is not.
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
      // All datetimes are ISO-8601 UTC (api-docs §1.9). `tryParse` keeps one
      // malformed timestamp from taking down a whole page of notifications;
      // the epoch fallback sorts such an item last under the default
      // `created_at:desc`, which is where an unreadable item belongs.
      createdAt: DateTime.tryParse(createdAt)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(updatedAt)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
