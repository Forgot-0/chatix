// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'position_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PositionModel _$PositionModelFromJson(Map<String, dynamic> json) =>
    PositionModel(
      id: json['id'] as String,
      projectId: (json['project_id'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String,
      responsibilities: json['responsibilities'] as String?,
      requiredSkills:
          (json['required_skills'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isOpen: json['is_open'] as bool,
      locationType: json['location_type'] as String,
      expectedLoad: json['expected_load'] as String,
    );

Map<String, dynamic> _$PositionModelToJson(PositionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'project_id': instance.projectId,
      'title': instance.title,
      'description': instance.description,
      'responsibilities': instance.responsibilities,
      'required_skills': instance.requiredSkills,
      'is_open': instance.isOpen,
      'location_type': instance.locationType,
      'expected_load': instance.expectedLoad,
    };
