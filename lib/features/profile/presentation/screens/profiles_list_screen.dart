import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/presentation/providers/profile_list_provider.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_avatar.dart';

/// `GET /profiles/` (api-docs §4.2), the first list screen built on top of
/// `PageResult`/`ProfileListController` — the intended template for the
/// other paginated lists (projects, positions, notifications, ...) to
/// follow.
class ProfilesListScreen extends ConsumerStatefulWidget {
  const ProfilesListScreen({super.key});

  @override
  ConsumerState<ProfilesListScreen> createState() => _ProfilesListScreenState();
}

class _ProfilesListScreenState extends ConsumerState<ProfilesListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(profileListProvider.notifier).loadMore();
    }
  }

  void _search(String value) {
    ref.read(profileListProvider.notifier).search(displayName: value.trim().isEmpty ? null : value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(profileListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search by name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: _search,
            ),
          ),
          Expanded(
            child: listState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ListError(
                message: error is Failure ? error.message : 'Could not load profiles',
                onRetry: () => ref.read(profileListProvider.notifier).refresh(),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return const Center(child: Text('No profiles found'));
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(profileListProvider.notifier).refresh(),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: state.items.length + (state.hasNext ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= state.items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final profile = state.items[index];
                      return ListTile(
                        leading: ProfileAvatar(profile: profile, radius: 20),
                        title: Text(profile.displayName ?? 'Profile #${profile.id}'),
                        subtitle: profile.specialization != null
                            ? Text(profile.specialization!)
                            : null,
                        onTap: () => context.push(AppConstants.profileDetailRoute(profile.id)),
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

class _ListError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ListError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
