import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/project/domain/entities/position_entity.dart';
import 'package:chatix/features/project/presentation/providers/position_detail_provider.dart';
import 'package:chatix/features/project/presentation/providers/project_detail_provider.dart';
import 'package:chatix/features/project/presentation/providers/project_providers.dart';
import 'package:chatix/features/project/presentation/utils/project_permissions.dart';
import 'package:chatix/features/project/presentation/widgets/project_common.dart';

class PositionDetailScreen extends ConsumerWidget {
  const PositionDetailScreen({
    super.key,
    required this.projectId,
    required this.positionId,
  });

  final int projectId;
  final String positionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(positionDetailProvider(positionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(positionAsync.value?.title ?? 'Position'),
      ),
      body: positionAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: 'Failed to load position',
          onRetry: () => ref.invalidate(
            positionDetailProvider(positionId),
        ),
        ),
        data: (position) => _PositionBody(position: position),
      ),
    );
  }
}

class _PositionBody extends ConsumerWidget {
  const _PositionBody({
    required this.position,
  });

  final PositionEntity position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUserId = ref.watch(authProvider).value?.id;

    final project =
        ref.watch(projectDetailProvider(position.projectId)).value;

    final me = (project != null && myUserId != null)
        ? project.membershipOf(myUserId)
        : null;

    final canReview = hasProjectPermission(
      me,
      ProjectPermissions.positionDelete,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          position.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Chip(
              label: Text(
                locationTypeLabel(position.locationType),
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                'Load: ${expectedLoadLabel(position.expectedLoad)}',
              ),
            ),
            const SizedBox(width: 8),
            if (!position.isOpen)
              const Chip(
                label: Text('Closed'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(position.description),
        if (position.responsibilities != null) ...[
          const SizedBox(height: 16),
          Text(
            'Responsibilities',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(position.responsibilities!),
        ],
        if (position.requiredSkills.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Required skills',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: position.requiredSkills
                .map((skill) => Chip(label: Text(skill)))
                .toList(),
          ),
        ],
        const SizedBox(height: 24),
        if (position.isOpen && myUserId != null)
          FilledButton.icon(
            icon: const Icon(Icons.send_outlined),
            label: const Text('Apply'),
            onPressed: () =>
                _showApplyDialog(context, ref, position.id),
          ),
        if (canReview) ...[
          const Divider(height: 40),
          Text(
            'Pending applications',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _ApplicationsSection(
            positionId: position.id,
          ),
        ],
      ],
    );
  }

  Future<void> _showApplyDialog(
    BuildContext context,
    WidgetRef ref,
    String positionId,
  ) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply to position'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Message (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            child: const Text('Submit'),
            onPressed: () async {
              final text = controller.text.trim();

              final result = await ref
                  .read(applyToPositionUseCaseProvider)
                  .execute(
                    positionId,
                    message: text.isEmpty ? null : text,
                  );

              if (!dialogContext.mounted) return;

              result.fold(
                (failure) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(failure.message),
                    ),
                  );
                },
                (_) {
                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Application submitted'),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApplicationsSection extends ConsumerWidget {
  const _ApplicationsSection({
    required this.positionId,
  });

  final String positionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications =
        ref.watch(positionApplicationsProvider(positionId));

    final action =
        ref.watch(positionApplicationActionProvider);

    final loading = action.isLoading;

    return applications.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: 'Failed to load applications',
          onRetry: () => ref.invalidate(
          positionApplicationsProvider(positionId),
        ),
      ),
      data: (apps) {
        if (apps.isEmpty) {
          return const Text(
            'No pending applications',
          );
        }

        return Column(
          children: apps.map((app) {
            return Card(
              child: ListTile(
                title: Text(
                  'Candidate #${app.candidateId}',
                ),
                subtitle: app.message == null
                    ? null
                    : Text(app.message!),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Approve',
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      onPressed: loading
                          ? null
                          : () => _approve(
                                context,
                                ref,
                                app.id,
                              ),
                    ),
                    IconButton(
                      tooltip: 'Reject',
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: Colors.red,
                      ),
                      onPressed: loading
                          ? null
                          : () => _reject(
                                context,
                                ref,
                                app.id,
                              ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    String applicationId,
  ) async {
    final error = await ref
        .read(positionApplicationActionProvider.notifier)
        .approve(
          applicationId: applicationId,
          positionId: positionId,
        );

    if (!context.mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    String applicationId,
  ) async {
    final error = await ref
        .read(positionApplicationActionProvider.notifier)
        .reject(
          applicationId: applicationId,
          positionId: positionId,
        );

    if (!context.mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
    }
  }
}