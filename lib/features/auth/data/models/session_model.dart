import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:chatix/features/auth/domain/entities/session_entity.dart';

part 'session_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class SessionModel extends Equatable {
  const SessionModel({
    required this.id,
    required this.userId,
    required this.deviceInfo,
    required this.userAgent,
    required this.lastActivity,
    required this.isActive,
  });

  final int id;
  final int userId;

  @JsonKey(defaultValue: '')
  final String deviceInfo;

  @JsonKey(defaultValue: '')
  final String userAgent;

  final String? lastActivity;

  @JsonKey(defaultValue: false)
  final bool isActive;

  factory SessionModel.fromJson(Map<String, dynamic> json) =>
      _$SessionModelFromJson(json);

  Map<String, dynamic> toJson() => _$SessionModelToJson(this);

  @override
  List<Object?> get props => [
    id,
    userId,
    deviceInfo,
    userAgent,
    lastActivity,
    isActive,
  ];
}

extension SessionModelX on SessionModel {
  SessionEntity toEntity() => SessionEntity(
    id: id,
    userId: userId,
    deviceInfo: deviceInfo,
    userAgent: userAgent,
    lastActivity: lastActivity == null
        ? null
        : DateTime.tryParse(lastActivity!),
    isActive: isActive,
  );
}
