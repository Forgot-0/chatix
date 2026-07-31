import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/presentation/providers/my_invites_provider.dart';
import 'package:chatix/features/project/presentation/providers/my_projects_provider.dart';
import 'package:chatix/features/project/presentation/widgets/project_common.dart';

/// `GET /profiles/invites/my/` 🔒 (api-docs §5.2) — incoming project invites
/// with an "Accept" action (`POST /projects/{id}/members/accept/`).
class MyInvitesScreen extends ConsumerWidget {
  const MyInvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(myInvitesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My invites')),
      body: invitesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ProjectErrorView(
          message: error is Failure ? error.message : 'Failed to load invites',
          onRetry: () => ref.read(myInvitesProvider.notifier).refresh(),
        ),
        data: (invites) {
          if (invites.isEmpty) {
            return const Center(child: Text('No pending invites'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(myInvitesProvider.notifier).refresh(),
            child: ListView.builder(
              itemCount: invites.length,
              itemBuilder: (context, index) {
                final invite = invites[index];
                final projectName = invite.project?.name ?? 'Project #${invite.projectId}';
                return ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(projectName),
                  subtitle: Text(
                    'Role: ${invite.role?.name ?? '—'} · '
                    '${memberStatusLabel(invite.status)}',
                  ),
                  trailing: FilledButton(
                    onPressed: () => _accept(context, ref, invite.projectId),
                    child: const Text('Accept'),
                  ),
                  onTap: () =>
                      context.push(AppConstants.projectDetailRoute(invite.projectId)),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref, int projectId) async {
    final error = await ref.read(myInvitesProvider.notifier).accept(projectId);
    if (!context.mounted) return;
    if (error == null) {
      // Now a member — refresh "my projects" so it appears there.
      ref.invalidate(myProjectsProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invite accepted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
