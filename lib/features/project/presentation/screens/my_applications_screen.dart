import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/entities/application_entity.dart';
import 'package:chatix/features/project/presentation/providers/my_applications_provider.dart';
import 'package:chatix/features/project/presentation/widgets/project_common.dart';

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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ProjectErrorView(
                message: error is Failure ? error.message : 'Failed to load applications',
                onRetry: () => ref.read(myApplicationsProvider.notifier).refresh(),
              ),
              data: (apps) {
                if (apps.isEmpty) {
                  return const Center(child: Text('No applications with this status'));
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
                            context.push(AppConstants.positionDetailRoute(app.positionId)),
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
