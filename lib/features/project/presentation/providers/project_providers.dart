import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/project/data/repositories/project_repository_impl.dart';
import 'package:chatix/features/project/domain/usecases/accept_invite_use_case.dart';
import 'package:chatix/features/project/domain/usecases/apply_to_position_use_case.dart';
import 'package:chatix/features/project/domain/usecases/approve_application_use_case.dart';
import 'package:chatix/features/project/domain/usecases/change_member_role_use_case.dart';
import 'package:chatix/features/project/domain/usecases/create_position_use_case.dart';
import 'package:chatix/features/project/domain/usecases/create_project_use_case.dart';
import 'package:chatix/features/project/domain/usecases/delete_position_use_case.dart';
import 'package:chatix/features/project/domain/usecases/delete_project_use_case.dart';
import 'package:chatix/features/project/domain/usecases/get_applications_use_case.dart';
import 'package:chatix/features/project/domain/usecases/get_my_applications_use_case.dart';
import 'package:chatix/features/project/domain/usecases/get_my_invites_use_case.dart';
import 'package:chatix/features/project/domain/usecases/get_my_projects_use_case.dart';
import 'package:chatix/features/project/domain/usecases/get_position_applications_use_case.dart';
import 'package:chatix/features/project/domain/usecases/get_position_use_case.dart';
import 'package:chatix/features/project/domain/usecases/get_positions_use_case.dart';
import 'package:chatix/features/project/domain/usecases/get_project_positions_use_case.dart';
import 'package:chatix/features/project/domain/usecases/get_project_roles_use_case.dart';
import 'package:chatix/features/project/domain/usecases/get_project_use_case.dart';
import 'package:chatix/features/project/domain/usecases/get_projects_use_case.dart';
import 'package:chatix/features/project/domain/usecases/invite_member_use_case.dart';
import 'package:chatix/features/project/domain/usecases/reject_application_use_case.dart';
import 'package:chatix/features/project/domain/usecases/update_member_permissions_use_case.dart';
import 'package:chatix/features/project/domain/usecases/update_position_use_case.dart';
import 'package:chatix/features/project/domain/usecases/update_project_use_case.dart';

/// Domain-layer DI for the project feature. `projectRepositoryProvider` lives
/// next to its implementation in `project_repository_impl.dart` (mirrors the
/// auth/profile convention) — import that file directly where the repository
/// itself is needed.

// --- Projects ---------------------------------------------------------------

final createProjectUseCaseProvider = Provider<CreateProjectUseCase>((ref) {
  return CreateProjectUseCase(ref.watch(projectRepositoryProvider));
});

final getProjectsUseCaseProvider = Provider<GetProjectsUseCase>((ref) {
  return GetProjectsUseCase(ref.watch(projectRepositoryProvider));
});

final getMyProjectsUseCaseProvider = Provider<GetMyProjectsUseCase>((ref) {
  return GetMyProjectsUseCase(ref.watch(projectRepositoryProvider));
});

final getProjectUseCaseProvider = Provider<GetProjectUseCase>((ref) {
  return GetProjectUseCase(ref.watch(projectRepositoryProvider));
});

final updateProjectUseCaseProvider = Provider<UpdateProjectUseCase>((ref) {
  return UpdateProjectUseCase(ref.watch(projectRepositoryProvider));
});

final deleteProjectUseCaseProvider = Provider<DeleteProjectUseCase>((ref) {
  return DeleteProjectUseCase(ref.watch(projectRepositoryProvider));
});

// --- Members & invites ------------------------------------------------------

final inviteMemberUseCaseProvider = Provider<InviteMemberUseCase>((ref) {
  return InviteMemberUseCase(ref.watch(projectRepositoryProvider));
});

final acceptInviteUseCaseProvider = Provider<AcceptInviteUseCase>((ref) {
  return AcceptInviteUseCase(ref.watch(projectRepositoryProvider));
});

final getMyInvitesUseCaseProvider = Provider<GetMyInvitesUseCase>((ref) {
  return GetMyInvitesUseCase(ref.watch(projectRepositoryProvider));
});

final changeMemberRoleUseCaseProvider = Provider<ChangeMemberRoleUseCase>((ref) {
  return ChangeMemberRoleUseCase(ref.watch(projectRepositoryProvider));
});

final updateMemberPermissionsUseCaseProvider = Provider<UpdateMemberPermissionsUseCase>((ref) {
  return UpdateMemberPermissionsUseCase(ref.watch(projectRepositoryProvider));
});

// --- Positions --------------------------------------------------------------

final createPositionUseCaseProvider = Provider<CreatePositionUseCase>((ref) {
  return CreatePositionUseCase(ref.watch(projectRepositoryProvider));
});

final getProjectPositionsUseCaseProvider = Provider<GetProjectPositionsUseCase>((ref) {
  return GetProjectPositionsUseCase(ref.watch(projectRepositoryProvider));
});

final getPositionsUseCaseProvider = Provider<GetPositionsUseCase>((ref) {
  return GetPositionsUseCase(ref.watch(projectRepositoryProvider));
});

final getPositionUseCaseProvider = Provider<GetPositionUseCase>((ref) {
  return GetPositionUseCase(ref.watch(projectRepositoryProvider));
});

final updatePositionUseCaseProvider = Provider<UpdatePositionUseCase>((ref) {
  return UpdatePositionUseCase(ref.watch(projectRepositoryProvider));
});

final deletePositionUseCaseProvider = Provider<DeletePositionUseCase>((ref) {
  return DeletePositionUseCase(ref.watch(projectRepositoryProvider));
});

final getPositionApplicationsUseCaseProvider = Provider<GetPositionApplicationsUseCase>((ref) {
  return GetPositionApplicationsUseCase(ref.watch(projectRepositoryProvider));
});

final applyToPositionUseCaseProvider = Provider<ApplyToPositionUseCase>((ref) {
  return ApplyToPositionUseCase(ref.watch(projectRepositoryProvider));
});

// --- Applications -----------------------------------------------------------

final getApplicationsUseCaseProvider = Provider<GetApplicationsUseCase>((ref) {
  return GetApplicationsUseCase(ref.watch(projectRepositoryProvider));
});

final getMyApplicationsUseCaseProvider = Provider<GetMyApplicationsUseCase>((ref) {
  return GetMyApplicationsUseCase(ref.watch(projectRepositoryProvider));
});

final approveApplicationUseCaseProvider = Provider<ApproveApplicationUseCase>((ref) {
  return ApproveApplicationUseCase(ref.watch(projectRepositoryProvider));
});

final rejectApplicationUseCaseProvider = Provider<RejectApplicationUseCase>((ref) {
  return RejectApplicationUseCase(ref.watch(projectRepositoryProvider));
});

// --- Project roles ----------------------------------------------------------

final getProjectRolesUseCaseProvider = Provider<GetProjectRolesUseCase>((ref) {
  return GetProjectRolesUseCase(ref.watch(projectRepositoryProvider));
});
