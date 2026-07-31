import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/project/domain/entities/application_entity.dart';
import 'package:chatix/features/project/domain/entities/position_entity.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/domain/entities/project_member_entity.dart';
import 'package:chatix/features/project/domain/entities/project_role_entity.dart';

/// `/projects`, `/positions`, `/applications`, `/project_roles` (api-docs §5).
///
/// Everything here requires authorization **except** `getPositions`,
/// `getPosition` and `getProjectRoles`, which are public (api-docs §5 intro).
/// The three domains are deliberately grouped behind one repository because
/// they're tightly coupled (a position belongs to a project, an application
/// belongs to a position); the *data* layer splits them into three
/// datasources (`project`/`position`/`application`) for readability.
abstract class ProjectRepository {
  // ---------------------------------------------------------------------------
  // Projects — api-docs §5.1
  // ---------------------------------------------------------------------------

  /// `POST /projects/` 🔒. Server responds `201` with an empty body, hence
  /// `void`. ⚠️ The long text field is sent as **`description`** here (it
  /// comes back as `full_description` on read — api-docs §5.1). Limit: max 3
  /// projects per user → `400 MAX_PROJECTS_LIMIT_EXCEEDED`.
  Future<Either<Failure, void>> createProject({
    required String name,
    required String slug,
    String? smallDescription,
    String? description,
    ProjectVisibility? visibility,
    Map<String, dynamic>? metaData,
    List<String>? tags,
  });

  /// `GET /projects/` 🔒 (api-docs §5.1).
  Future<Either<Failure, PageResult<ProjectEntity>>> getProjects({
    String? name,
    String? slug,
    List<String>? tags,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  /// `GET /projects/my/` 🔒 — projects the current user owns or is a member
  /// of (api-docs §5.1).
  Future<Either<Failure, PageResult<ProjectEntity>>> getMyProjects({
    int page = 1,
    int pageSize = 20,
  });

  /// `GET /projects/{project_id}/` 🔒 (api-docs §5.1).
  Future<Either<Failure, ProjectEntity>> getProject(int projectId);

  /// `PUT /projects/{project_id}/` 🔒 (api-docs §5.1). ⚠️ No `slug` (immutable
  /// after creation) and no `small_description`. Long text is `description`
  /// on the wire.
  Future<Either<Failure, void>> updateProject(
    int projectId, {
    String? name,
    String? description,
    ProjectVisibility? visibility,
    Map<String, dynamic>? metaData,
    List<String>? tags,
  });

  /// `DELETE /projects/{project_id}/` 🔒 — owner/admin only, `204`.
  Future<Either<Failure, void>> deleteProject(int projectId);

  // ---------------------------------------------------------------------------
  // Members & invites — api-docs §5.2
  // ---------------------------------------------------------------------------

  /// `POST /projects/{project_id}/invite/` 🔒 (requires `member:invite`).
  /// [roleId] is required — the backend does not auto-assign a default role
  /// (api-docs §9.2).
  Future<Either<Failure, void>> inviteMember(
    int projectId, {
    required int userId,
    required int roleId,
    Map<String, bool>? permissionsOverrides,
  });

  /// `POST /projects/{project_id}/members/accept/` 🔒 — accept **your own**
  /// invite (api-docs §5.2). Moves invited/pending → active.
  Future<Either<Failure, void>> acceptInvite(int projectId);

  /// `GET /profiles/invites/my/` 🔒 — the current user's incoming project
  /// invites. ⚠️ This lives under `/profiles`, NOT `/projects` — a real
  /// backend routing quirk documented in api-docs §5.2; each returned member
  /// carries its `project`.
  Future<Either<Failure, PageResult<ProjectMemberEntity>>> getMyInvites({
    int page = 1,
    int pageSize = 20,
  });

  /// `POST /projects/{project_id}/members/{user_id}/role/` 🔒 (requires a
  /// project role with the right; api-docs §5.2).
  Future<Either<Failure, void>> changeMemberRole(
    int projectId, {
    required int userId,
    required int roleId,
  });

  /// `PUT /projects/{project_id}/members/{user_id}/permissions/` 🔒 — replaces
  /// the member's permission overrides (api-docs §5.2). Gate the UI on
  /// `member:udpate`/`permission:update`.
  Future<Either<Failure, void>> updateMemberPermissions(
    int projectId, {
    required int userId,
    required Map<String, bool> permissionsOverrides,
  });

  // ---------------------------------------------------------------------------
  // Positions — api-docs §5.3
  // ---------------------------------------------------------------------------

  /// `POST /projects/{project_id}/positions/` 🔒. Limit: max 5 **open**
  /// positions per project → `400 MAX_POSITIONS_PER_PROJECT_LIMIT_EXCEEDED`.
  Future<Either<Failure, void>> createPosition(
    int projectId, {
    required String title,
    required String description,
    String? responsibilities,
    List<String>? requiredSkills,
    PositionLocationType? locationType,
    PositionExpectedLoad? expectedLoad,
  });

  /// `GET /projects/{project_id}/positions/` 🔒 (auth required despite looking
  /// like a public list — api-docs §5.3).
  Future<Either<Failure, PageResult<PositionEntity>>> getProjectPositions(
    int projectId, {
    String? title,
    List<String>? requiredSkills,
    bool isOpen = true,
    PositionLocationType? locationType,
    PositionExpectedLoad? expectedLoad,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  /// `GET /positions/` 🔓 public (api-docs §5.3).
  Future<Either<Failure, PageResult<PositionEntity>>> getPositions({
    int? projectId,
    String? title,
    List<String>? requiredSkills,
    bool isOpen = true,
    PositionLocationType? locationType,
    PositionExpectedLoad? expectedLoad,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  /// `GET /positions/{position_id}/` 🔓 public (api-docs §5.3). [positionId]
  /// is a UUID.
  Future<Either<Failure, PositionEntity>> getPosition(String positionId);

  /// `PUT /positions/{position_id}/` 🔒 (api-docs §5.3).
  Future<Either<Failure, void>> updatePosition(
    String positionId, {
    String? title,
    String? description,
    String? responsibilities,
    List<String>? requiredSkills,
    PositionLocationType? locationType,
    PositionExpectedLoad? expectedLoad,
  });

  /// `DELETE /positions/{position_id}/` 🔒 (api-docs §5.3), `204`.
  Future<Either<Failure, void>> deletePosition(String positionId);

  /// `GET /positions/{position_id}/applications/` 🔒 — applications to a
  /// position, for the position's owner/maintainer (api-docs §5.3).
  Future<Either<Failure, PageResult<ApplicationEntity>>> getPositionApplications(
    String positionId, {
    int? projectId,
    int? candidateId,
    ApplicationStatus? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  /// `POST /positions/{position_id}/applications/` 🔒 — apply to a position,
  /// optional [message] (api-docs §5.3), `201`.
  Future<Either<Failure, void>> applyToPosition(
    String positionId, {
    String? message,
  });

  // ---------------------------------------------------------------------------
  // Applications — api-docs §5.4
  // ---------------------------------------------------------------------------

  /// `GET /applications/` 🔒 (api-docs §5.4).
  Future<Either<Failure, PageResult<ApplicationEntity>>> getApplications({
    int? projectId,
    String? positionId,
    int? candidateId,
    ApplicationStatus? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  /// `GET /applications/me/` 🔒 — the current candidate's own applications
  /// (api-docs §5.4).
  Future<Either<Failure, PageResult<ApplicationEntity>>> getMyApplications({
    String? positionId,
    int? projectId,
    ApplicationStatus? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  /// `POST /applications/{application_id}/approve/` 🔒 (api-docs §5.4).
  /// `409 NOT_PENDING_APPLICATION` if already decided.
  Future<Either<Failure, void>> approveApplication(String applicationId);

  /// `POST /applications/{application_id}/reject/` 🔒 (api-docs §5.4).
  /// `409 NOT_PENDING_APPLICATION` if already decided.
  Future<Either<Failure, void>> rejectApplication(String applicationId);

  // ---------------------------------------------------------------------------
  // Project roles — api-docs §5.5
  // ---------------------------------------------------------------------------

  /// `GET /project_roles/` 🔓 public, read-only (api-docs §5.5). There are no
  /// create/update endpoints for project roles.
  Future<Either<Failure, PageResult<ProjectRoleEntity>>> getProjectRoles({
    String? name,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });
}
