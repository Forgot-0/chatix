// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionModel _$SessionModelFromJson(Map<String, dynamic> json) => SessionModel(
  id: (json['id'] as num).toInt(),
  userId: (json['user_id'] as num).toInt(),
  deviceInfo: json['device_info'] as String? ?? '',
  userAgent: json['user_agent'] as String? ?? '',
  lastActivity: json['last_activity'] as String?,
  isActive: json['is_active'] as bool? ?? false,
);

Map<String, dynamic> _$SessionModelToJson(SessionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'device_info': instance.deviceInfo,
      'user_agent': instance.userAgent,
      'last_activity': instance.lastActivity,
      'is_active': instance.isActive,
    };
