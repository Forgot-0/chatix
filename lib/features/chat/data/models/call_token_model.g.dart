// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_token_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CallTokenModel _$CallTokenModelFromJson(Map<String, dynamic> json) =>
    CallTokenModel(
      token: json['token'] as String,
      slug: json['slug'] as String,
      livekitUrl: json['livekit_url'] as String,
    );

Map<String, dynamic> _$CallTokenModelToJson(CallTokenModel instance) =>
    <String, dynamic>{
      'token': instance.token,
      'slug': instance.slug,
      'livekit_url': instance.livekitUrl,
    };
