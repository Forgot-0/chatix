import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/project/domain/entities/application_entity.dart';

part 'application_model.g.dart';

/// `ApplicationDTO` (api-docs §5.4). [id]/[positionId] are UUID strings;
/// [projectId]/[candidateId] are ints. [status] is mapped to
/// [ApplicationStatus] in [toEntity].
@JsonSerializable(fieldRename: FieldRename.snake)
class ApplicationModel extends Equatable {
  final String id;
  final int projectId;
  final String positionId;
  final int candidateId;
  final String status;
  final String? message;
  final int? decidedBy;
  final String? decidedAt;

  const ApplicationModel({
    required this.id,
    required this.projectId,
    required this.positionId,
    required this.candidateId,
    required this.status,
    required this.message,
    required this.decidedBy,
    required this.decidedAt,
  });

  @override
  List<Object?> get props => [
    id,
    projectId,
    positionId,
    candidateId,
    status,
    message,
    decidedBy,
    decidedAt,
  ];

  factory ApplicationModel.fromJson(Map<String, dynamic> json) => _$ApplicationModelFromJson(json);

  Map<String, dynamic> toJson() => _$ApplicationModelToJson(this);
}

extension ApplicationModelX on ApplicationModel {
  ApplicationEntity toEntity() {
    return ApplicationEntity(
      id: id,
      projectId: projectId,
      positionId: positionId,
      candidateId: candidateId,
      status: ApplicationStatus.fromWire(status),
      message: message,
      decidedBy: decidedBy,
      decidedAt: decidedAt != null ? DateTime.parse(decidedAt!) : null,
    );
  }
}
