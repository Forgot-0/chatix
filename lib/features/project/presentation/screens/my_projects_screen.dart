import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/features/project/domain/usecases/create_project_use_case.dart';
import 'package:chatix/features/project/presentation/providers/my_projects_provider.dart';
import 'package:chatix/features/project/presentation/screens/projects_list_screen.dart';
import 'package:chatix/core/router/app_routes.dart';

/// `GET /projects/my/` 🔒 (api-docs §5.1). Also the natural home for the
/// "create project" affordance: once the user owns
/// [CreateProjectUseCase.maxProjectsPerUser] projects the FAB is disabled with
/// a hint (the server still enforces `MAX_PROJECTS_LIMIT_EXCEEDED` — this is
/// just to avoid a guaranteed-400 round-trip, api-docs §5.1).
class MyProjectsScreen extends ConsumerStatefulWidget {
  const MyProjectsScreen({super.key});

  @override
  ConsumerState<MyProjectsScreen> createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends ConsumerState<MyProjectsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(myProjectsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProjectsProvider);
    final total = state.value?.total ?? 0;
    final atLimit = total >= CreateProjectUseCase.maxProjectsPerUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My projects')),
      body: state.when(
        loading: () => const AppListSkeleton(),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: 'Failed to load your projects',
          onRetry: () => ref.read(myProjectsProvider.notifier).refresh(),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(myProjectsProvider.notifier).refresh(),
              child: AppEmptyState(
                icon: Icons.folder_open_outlined,
                title: "You aren't in any projects yet",
                message: 'Create one to get started.',
                action: FilledButton.icon(
                  onPressed: () => context.push(CreateProjectRoute.location),
                  icon: const Icon(Icons.add),
                  label: const Text('New project'),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(myProjectsProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: data.items.length + (data.hasNext ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= data.items.length) {
                  return const AppLoadMoreIndicator();
                }
                return ProjectListTile(project: data.items[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: atLimit
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Limit reached: at most '
                      '${CreateProjectUseCase.maxProjectsPerUser} projects per user',
                    ),
                  ),
                )
            : () => context.push(CreateProjectRoute.location),
        backgroundColor: atLimit ? Theme.of(context).disabledColor : null,
        icon: const Icon(Icons.add),
        label: Text(atLimit ? 'Limit reached' : 'New project'),
      ),
    );
  }
}
