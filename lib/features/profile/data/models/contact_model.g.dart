// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContactModel _$ContactModelFromJson(Map<String, dynamic> json) => ContactModel(
  profileId: (json['profile_id'] as num).toInt(),
  provider: json['provider'] as String,
  contact: json['contact'] as String,
);

Map<String, dynamic> _$ContactModelToJson(ContactModel instance) =>
    <String, dynamic>{
      'profile_id': instance.profileId,
      'provider': instance.provider,
      'contact': instance.contact,
    };
