import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/presentation/providers/project_list_provider.dart';
import 'package:chatix/core/router/app_routes.dart';

/// `GET /projects/` 🔒 (api-docs §5.1). Auth-required list with name + tag
/// filters. ⚠️ Unlike `ProfilesListScreen`, there is no public read path in
/// this module, so this screen assumes an authenticated session.
class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _tagsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _nameController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(projectListProvider.notifier).loadMore();
    }
  }

  void _search() {
    final name = _nameController.text.trim();
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    ref.read(projectListProvider.notifier).search(
          name: name.isEmpty ? null : name,
          tags: tags.isEmpty ? null : tags,
        );
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            tooltip: 'My projects',
            icon: const Icon(Icons.folder_shared_outlined),
            onPressed: () => context.push(MyProjectsRoute.location),
          ),
          IconButton(
            tooltip: 'My invites',
            icon: const Icon(Icons.mail_outline),
            onPressed: () => context.push(MyInvitesRoute.location),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma-separated)',
                    prefixIcon: Icon(Icons.label_outline),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.filter_alt_outlined),
                    label: const Text('Search'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: listState.when(
              // First fetch only — a pull-to-refresh keeps the old rows on
              // screen instead of flashing this (see ChatsListScreen).
              loading: () => const AppListSkeleton(),
              error: (error, _) => AppErrorState(
                error: error,
                fallbackMessage: 'Failed to load projects',
                onRetry: () => ref.read(projectListProvider.notifier).refresh(),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => ref.read(projectListProvider.notifier).refresh(),
                    child: const AppEmptyState(
                      icon: Icons.workspaces_outline,
                      title: 'No projects found',
                      message: 'Try different filters, or create your own project.',
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(projectListProvider.notifier).refresh(),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: state.items.length + (state.hasNext ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= state.items.length) {
                        return const AppLoadMoreIndicator();
                      }
                      return ProjectListTile(project: state.items[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(CreateProjectRoute.location),
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
    );
  }
}

/// Reusable project row — also used by `MyProjectsScreen`.
class ProjectListTile extends StatelessWidget {
  const ProjectListTile({super.key, required this.project});

  final ProjectEntity project;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.workspaces_outline)),
      title: Text(project.name),
      subtitle: Text(
        project.smallDescription ?? project.fullDescription ?? project.slug,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _VisibilityChip(visibility: project.visibility),
      onTap: () => context.push(ProjectDetailRoute(project.id).location),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({required this.visibility});

  final ProjectVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (visibility) {
      ProjectVisibility.private => (Icons.lock_outline, 'Private'),
      ProjectVisibility.internal => (Icons.groups_outlined, 'Internal'),
      ProjectVisibility.public => (Icons.public, 'Public'),
    };
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}