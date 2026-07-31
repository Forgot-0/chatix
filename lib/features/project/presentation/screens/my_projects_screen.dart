import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/usecases/create_project_use_case.dart';
import 'package:chatix/features/project/presentation/providers/my_projects_provider.dart';
import 'package:chatix/features/project/presentation/screens/projects_list_screen.dart';
import 'package:chatix/features/project/presentation/widgets/project_common.dart';

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ProjectErrorView(
          message: error is Failure ? error.message : 'Failed to load your projects',
          onRetry: () => ref.read(myProjectsProvider.notifier).refresh(),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return const Center(child: Text("You aren't in any projects yet"));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(myProjectsProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: data.items.length + (data.hasNext ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= data.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
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
            : () => context.push(AppConstants.createProjectRoute),
        backgroundColor: atLimit ? Theme.of(context).disabledColor : null,
        icon: const Icon(Icons.add),
        label: Text(atLimit ? 'Limit reached' : 'New project'),
      ),
    );
  }
}
