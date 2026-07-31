// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'application_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApplicationModel _$ApplicationModelFromJson(Map<String, dynamic> json) =>
    ApplicationModel(
      id: json['id'] as String,
      projectId: (json['project_id'] as num).toInt(),
      positionId: json['position_id'] as String,
      candidateId: (json['candidate_id'] as num).toInt(),
      status: json['status'] as String,
      message: json['message'] as String?,
      decidedBy: (json['decided_by'] as num?)?.toInt(),
      decidedAt: json['decided_at'] as String?,
    );

Map<String, dynamic> _$ApplicationModelToJson(ApplicationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'project_id': instance.projectId,
      'position_id': instance.positionId,
      'candidate_id': instance.candidateId,
      'status': instance.status,
      'message': instance.message,
      'decided_by': instance.decidedBy,
      'decided_at': instance.decidedAt,
    };
