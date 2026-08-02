import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/features/project/domain/entities/application_entity.dart';
import 'package:chatix/features/project/presentation/providers/my_applications_provider.dart';
import 'package:chatix/features/project/presentation/widgets/project_common.dart';
import 'package:chatix/core/router/app_routes.dart';

/// `GET /applications/me/` 🔒 (api-docs §5.4) — the current candidate's own
/// applications, filterable by status. ⚠️ The server defaults the filter to
/// `pending`, so this screen starts on the "Pending" chip to match.
class MyApplicationsScreen extends ConsumerWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(myApplicationsProvider);
    final controller = ref.read(myApplicationsProvider.notifier);
    final activeStatus = controller.status;

    return Scaffold(
      appBar: AppBar(title: const Text('My applications')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: ApplicationStatus.values.map((status) {
                return ChoiceChip(
                  label: Text(applicationStatusLabel(status)),
                  selected: activeStatus == status,
                  onSelected: (_) => controller.setStatus(status),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: appsAsync.when(
              loading: () => const AppListSkeleton(),
              error: (error, _) => AppErrorState(
                error: error,
                fallbackMessage: 'Failed to load applications',
                onRetry: () => ref.read(myApplicationsProvider.notifier).refresh(),
              ),
              data: (apps) {
                if (apps.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => ref.read(myApplicationsProvider.notifier).refresh(),
                    child: const AppEmptyState(
                      icon: Icons.description_outlined,
                      title: 'No applications with this status',
                      message: 'Try a different status filter or refresh.',
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(myApplicationsProvider.notifier).refresh(),
                  child: ListView.builder(
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      return ListTile(
                        leading: Icon(
                          Icons.description_outlined,
                          color: applicationStatusColor(app.status),
                        ),
                        title: Text('Position ${app.positionId}'),
                        subtitle: Text(
                          app.message ?? 'Project #${app.projectId}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Chip(
                          label: Text(applicationStatusLabel(app.status)),
                          backgroundColor:
                              applicationStatusColor(app.status).withValues(alpha: 0.15),
                        ),
                        onTap: () =>
                            context.push(PositionDetailRoute(
                          projectId: app.projectId,
                          positionId: app.positionId,
                        ).location),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
