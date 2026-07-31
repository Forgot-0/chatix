import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/domain/entities/project_role_entity.dart';
import 'package:chatix/features/project/presentation/providers/project_providers.dart';

/// `GET /projects/{id}/` (api-docs §5.1) for a single project, keyed by
/// [projectId]. A `FutureProvider.family` is enough — mutations (invite,
/// change role, update permissions, edit) simply `ref.invalidate` this entry
/// afterwards so the detail view refetches with fresh `memberships`.
final projectDetailProvider = FutureProvider.family<ProjectEntity, int>((ref, projectId) async {
  final result = await ref.watch(getProjectUseCaseProvider).execute(projectId);
  return result.fold((failure) => throw failure, (project) => project);
});

/// `GET /project_roles/` 🔓 (api-docs §5.5) — the seeded project roles, used to
/// populate role pickers when inviting a member or changing a member's role.
/// Read-only and effectively static, so a single cached fetch is plenty
/// (kept alive for the session; `pageSize` 100 comfortably covers the handful
/// of seeded roles).
final projectRolesProvider = FutureProvider<List<ProjectRoleEntity>>((ref) async {
  final result = await ref.watch(getProjectRolesUseCaseProvider).execute(pageSize: 100);
  return result.fold((failure) => throw failure, (page) => page.items);
});
