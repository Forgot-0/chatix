import 'package:equatable/equatable.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/domain/entities/project_role_entity.dart';

/// Membership lifecycle status (api-docs §5.1/§5.2). ⚠️ Five values — do
/// **not** confuse this with `ApplicationStatus` (pending/accepted/rejected),
/// which is a different enum on a different entity. `pending` exists in
/// *both* enums but means different things.
///
/// Flow: an invite is created as [invited]; `members/accept/` moves
/// [invited]/[pending] → [active] (api-docs §5.2).
enum ProjectMemberStatus {
  invited,
  pending,
  active,
  suspended,
  removed;

  String get wire => name;

  static ProjectMemberStatus fromWire(String? value) {
    return ProjectMemberStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ProjectMemberStatus.invited,
    );
  }
}

/// `ProjectMemberDTO` / `MemberDTO` (api-docs §5.1, §5.2). The same shape is
/// embedded inside `ProjectDTO.memberships` and returned as the item type of
/// `GET /profiles/invites/my/` — in the latter case [project] is populated so
/// the "my invites" screen can show which project each invite belongs to.
class ProjectMemberEntity extends Equatable {
  final int id;
  final int projectId;
  final int userId;

  /// `null` when a member was invited without an explicit role. The backend
  /// does **not** auto-fill a default project role (unlike chats), so an
  /// invite should always carry a `role_id` (api-docs §9.2).
  final int? roleId;

  final ProjectMemberStatus status;
  final int? invitedBy;
  final DateTime? joinedAt;

  /// Per-member permission overrides layered on top of [role]'s matrix
  /// (api-docs §5.2, §10.6). Keys are permission strings (see
  /// [ProjectPermissions]); a present key wins over the role's value.
  final Map<String, bool> permissionsOverrides;

  final ProjectRoleEntity? role;

  /// Only populated by `GET /profiles/invites/my/` (`MemberDTO.project`,
  /// api-docs §5.2) — `null` for memberships embedded inside a `ProjectDTO`
  /// (where the parent project is already the enclosing object).
  final ProjectEntity? project;

  const ProjectMemberEntity({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.roleId,
    required this.status,
    required this.invitedBy,
    required this.joinedAt,
    required this.permissionsOverrides,
    required this.role,
    this.project,
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
}
