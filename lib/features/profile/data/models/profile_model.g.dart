// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileModel _$ProfileModelFromJson(Map<String, dynamic> json) => ProfileModel(
  id: (json['id'] as num).toInt(),
  avatars: (json['avatars'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, Map<String, String>.from(e as Map)),
  ),
  specialization: json['specialization'] as String?,
  displayName: json['display_name'] as String?,
  bio: json['bio'] as String?,
  dateBirthday: json['date_birthday'] as String?,
  skills: (json['skills'] as List<dynamic>).map((e) => e as String).toList(),
  contacts: (json['contacts'] as List<dynamic>)
      .map((e) => ContactModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ProfileModelToJson(ProfileModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'avatars': instance.avatars,
      'specialization': instance.specialization,
      'display_name': instance.displayName,
      'bio': instance.bio,
      'date_birthday': instance.dateBirthday,
      'skills': instance.skills,
      'contacts': instance.contacts,
    };
