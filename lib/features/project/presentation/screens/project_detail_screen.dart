import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/domain/entities/project_member_entity.dart';
import 'package:chatix/features/project/presentation/providers/project_detail_provider.dart';
import 'package:chatix/features/project/presentation/providers/position_detail_provider.dart';
import 'package:chatix/features/project/presentation/providers/my_projects_provider.dart';
import 'package:chatix/features/project/presentation/providers/project_providers.dart';
import 'package:chatix/features/project/presentation/utils/project_permissions.dart';
import 'package:chatix/features/project/presentation/widgets/project_common.dart';
import 'package:chatix/features/project/presentation/widgets/project_member_management.dart';
import 'package:chatix/features/project/presentation/widgets/create_position_dialog.dart';

/// `GET /projects/{id}/` 🔒 (api-docs §5.1) with three tabs: Info, Members,
/// Positions. Management controls (invite / change role / edit permissions /
/// create position) are shown only when the current user's membership grants
/// the matching permission — resolved via [hasProjectPermission] against the
/// §9.2 matrix (see api-docs §10.6).
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));
    final myUserId = ref.watch(authProvider).value?.id;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(projectAsync.value?.name ?? 'Project'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Info', icon: Icon(Icons.info_outline)),
              Tab(text: 'Members', icon: Icon(Icons.groups_outlined)),
              Tab(text: 'Positions', icon: Icon(Icons.work_outline)),
            ],
          ),
        ),
        body: projectAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ProjectErrorView(
            message: error is Failure ? error.message : 'Failed to load project',
            onRetry: () => ref.invalidate(projectDetailProvider(projectId)),
          ),
          data: (project) {
            final me = myUserId == null ? null : project.membershipOf(myUserId);
            return TabBarView(
              children: [
                _InfoTab(project: project, me: me),
                _MembersTab(project: project, me: me),
                _PositionsTab(project: project, me: me),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.project, required this.me});

  final ProjectEntity project;
  final ProjectMemberEntity? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDelete = hasProjectPermission(me, ProjectPermissions.projectDelete);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(project.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('slug: ${project.slug}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Chip(label: Text(projectVisibilityLabel(project.visibility))),
            const SizedBox(width: 8),
            Text('Owner #${project.ownerId}'),
          ],
        ),
        if (project.smallDescription != null) ...[
          const SizedBox(height: 16),
          Text(project.smallDescription!, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
        if (project.fullDescription != null) ...[
          const SizedBox(height: 12),
          // Displayed from `full_description` (read side of the naming split).
          Text(project.fullDescription!),
        ],
        if (project.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: project.tags.map((t) => Chip(label: Text(t))).toList(),
          ),
        ],
        if (canDelete) ...[
          const SizedBox(height: 32),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete project'),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete project?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(deleteProjectUseCaseProvider).execute(project.id);
    if (!context.mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))),
      (_) {
        // Refresh the "my projects" list so the deleted project disappears.
        ref.invalidate(myProjectsProvider);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Project deleted')));
        context.pop();
      },
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.project, required this.me});

  final ProjectEntity project;
  final ProjectMemberEntity? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canInvite = hasProjectPermission(me, ProjectPermissions.memberInvite);
    // ⚠️ Backend typo preserved: the "can edit member" right is `member:udpate`.
    final canManage = hasProjectPermission(me, ProjectPermissions.memberUpdate);

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: project.memberships.length,
          itemBuilder: (context, index) {
            final member = project.memberships[index];
            return MemberListTile(
              projectId: project.id,
              member: member,
              canManage: canManage,
            );
          },
        ),
        if (canInvite)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => showInviteMemberDialog(context, ref, project.id),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Invite'),
            ),
          ),
      ],
    );
  }
}

class _PositionsTab extends ConsumerWidget {
  const _PositionsTab({required this.project, required this.me});

  final ProjectEntity project;
  final ProjectMemberEntity? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = hasProjectPermission(me, ProjectPermissions.positionCreate);
    final positionsAsync = ref.watch(projectPositionsProvider(project.id));

    return Stack(
      children: [
        positionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ProjectErrorView(
            message: error is Failure ? error.message : 'Failed to load positions',
            onRetry: () => ref.invalidate(projectPositionsProvider(project.id)),
          ),
          data: (positions) {
            if (positions.isEmpty) {
              return const Center(child: Text('No open positions'));
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: positions.length,
              itemBuilder: (context, index) {
                final p = positions[index];
                return ListTile(
                  leading: const Icon(Icons.work_outline),
                  title: Text(p.title),
                  subtitle: Text(
                    '${locationTypeLabel(p.locationType)} · '
                    '${expectedLoadLabel(p.expectedLoad)}'
                    '${p.isOpen ? '' : ' · closed'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppConstants.positionDetailRoute(p.id)),
                );
              },
            );
          },
        ),
        if (canCreate)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => showCreatePositionDialog(
                context,
                ref,
                projectId: project.id,
                currentOpenCount: positionsAsync.value?.where((p) => p.isOpen).length,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add position'),
            ),
          ),
      ],
    );
  }
}
