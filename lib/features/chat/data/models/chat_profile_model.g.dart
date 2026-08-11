// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatProfileModel _$ChatProfileModelFromJson(Map<String, dynamic> json) =>
    ChatProfileModel(
      userId: (json['user_id'] as num).toInt(),
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      avatarS3Key: json['avatar_s3_key'] as String?,
    );

Map<String, dynamic> _$ChatProfileModelToJson(ChatProfileModel instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'username': instance.username,
      'display_name': instance.displayName,
      'avatar_url': instance.avatarUrl,
      'avatar_s3_key': instance.avatarS3Key,
    };
