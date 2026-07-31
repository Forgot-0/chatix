// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_role_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProjectRoleModel _$ProjectRoleModelFromJson(Map<String, dynamic> json) =>
    ProjectRoleModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      permissions: (json['permissions'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, e as bool),
      ),
    );

Map<String, dynamic> _$ProjectRoleModelToJson(ProjectRoleModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'permissions': instance.permissions,
    };
