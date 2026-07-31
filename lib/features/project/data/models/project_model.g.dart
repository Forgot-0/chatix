// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProjectModel _$ProjectModelFromJson(Map<String, dynamic> json) => ProjectModel(
  id: (json['id'] as num).toInt(),
  ownerId: (json['owner_id'] as num).toInt(),
  name: json['name'] as String,
  slug: json['slug'] as String,
  smallDescription: json['small_description'] as String?,
  fullDescription: json['full_description'] as String?,
  visibility: json['visibility'] as String,
  metaData: json['meta_data'] as Map<String, dynamic>? ?? {},
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  memberships:
      (json['memberships'] as List<dynamic>?)
          ?.map((e) => ProjectMemberModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$ProjectModelToJson(ProjectModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'owner_id': instance.ownerId,
      'name': instance.name,
      'slug': instance.slug,
      'small_description': instance.smallDescription,
      'full_description': instance.fullDescription,
      'visibility': instance.visibility,
      'meta_data': instance.metaData,
      'tags': instance.tags,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'memberships': instance.memberships,
    };
