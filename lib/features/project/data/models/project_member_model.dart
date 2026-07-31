import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/project/data/models/project_model.dart';
import 'package:chatix/features/project/data/models/project_role_model.dart';
import 'package:chatix/features/project/domain/entities/project_member_entity.dart';

part 'project_member_model.g.dart';

/// `ProjectMemberDTO` / `MemberDTO` (api-docs §5.1, §5.2).
///
/// [status] is kept as the raw wire string and turned into
/// [ProjectMemberStatus] in [toEntity] (same model↔entity boundary approach
/// `ProfileModel` uses for its date field), so json_serializable never needs
/// an enum map here. [project] is only populated by `GET /profiles/invites/my/`.
@JsonSerializable(fieldRename: FieldRename.snake)
class ProjectMemberModel extends Equatable {
  final int id;
  final int projectId;
  final int userId;
  final int? roleId;
  final String status;
  final int? invitedBy;
  final String? joinedAt;
  final Map<String, bool> permissionsOverrides;
  final ProjectRoleModel? role;
  final ProjectModel? project;

  const ProjectMemberModel({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.roleId,
    required this.status,
    required this.invitedBy,
    required this.joinedAt,
    required this.permissionsOverrides,
    required this.role,
    required this.project,
  });

  @override
  List<Object?> get props => [
    id,
    projectId,
    userId,
    roleId,
    status,
    invitedBy,
    joinedAt,
    permissionsOverrides,
    role,
    project,
  ];

  factory ProjectMemberModel.fromJson(Map<String, dynamic> json) => _$ProjectMemberModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProjectMemberModelToJson(this);
}

extension ProjectMemberModelX on ProjectMemberModel {
  ProjectMemberEntity toEntity() {
    return ProjectMemberEntity(
      id: id,
      projectId: projectId,
      userId: userId,
      roleId: roleId,
      status: ProjectMemberStatus.fromWire(status),
      invitedBy: invitedBy,
      joinedAt: joinedAt != null ? DateTime.parse(joinedAt!) : null,
      permissionsOverrides: permissionsOverrides,
      role: role?.toEntity(),
      project: project?.toEntity(),
    );
  }
}
