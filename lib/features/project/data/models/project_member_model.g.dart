// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_member_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProjectMemberModel _$ProjectMemberModelFromJson(Map<String, dynamic> json) =>
    ProjectMemberModel(
      id: (json['id'] as num).toInt(),
      projectId: (json['project_id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      roleId: (json['role_id'] as num?)?.toInt(),
      status: json['status'] as String,
      invitedBy: (json['invited_by'] as num?)?.toInt(),
      joinedAt: json['joined_at'] as String?,
      permissionsOverrides: Map<String, bool>.from(
        json['permissions_overrides'] as Map,
      ),
      role: json['role'] == null
          ? null
          : ProjectRoleModel.fromJson(json['role'] as Map<String, dynamic>),
      project: json['project'] == null
          ? null
          : ProjectModel.fromJson(json['project'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ProjectMemberModelToJson(ProjectMemberModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'project_id': instance.projectId,
      'user_id': instance.userId,
      'role_id': instance.roleId,
      'status': instance.status,
      'invited_by': instance.invitedBy,
      'joined_at': instance.joinedAt,
      'permissions_overrides': instance.permissionsOverrides,
      'role': instance.role,
      'project': instance.project,
    };
