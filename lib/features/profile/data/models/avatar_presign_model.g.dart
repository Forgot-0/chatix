// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatar_presign_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AvatarPresignModel _$AvatarPresignModelFromJson(Map<String, dynamic> json) =>
    AvatarPresignModel(
      url: json['url'] as String,
      fields: Map<String, String>.from(json['fields'] as Map),
      keyBase: json['key_base'] as String,
    );

Map<String, dynamic> _$AvatarPresignModelToJson(AvatarPresignModel instance) =>
    <String, dynamic>{
      'url': instance.url,
      'fields': instance.fields,
      'key_base': instance.keyBase,
    };
