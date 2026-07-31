import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/project/domain/entities/project_member_entity.dart';
import 'package:chatix/features/project/presentation/providers/project_providers.dart';

/// `GET /profiles/invites/my/` (api-docs §5.2) — the current user's incoming
/// project invites, plus an [accept] action wired to
/// `POST /projects/{id}/members/accept/`. A single first page is loaded; on a
/// successful accept the accepted invite is removed from the local list
/// optimistically and the list is refetched to stay in sync.
class MyInvitesController extends AsyncNotifier<List<ProjectMemberEntity>> {
  @override
  Future<List<ProjectMemberEntity>> build() => _fetch();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Accepts the invite for [projectId]. Returns `null` on success or a
  /// human-readable error message the screen can show in a snackbar.
  Future<String?> accept(int projectId) async {
    final result = await ref.read(acceptInviteUseCaseProvider).execute(projectId);
    return result.fold(
      (failure) => failure.message,
      (_) {
        // Optimistically drop it, then refetch for authoritative state.
        final current = state.value ?? const [];
        state = AsyncValue.data(
          current.where((m) => m.projectId != projectId).toList(),
        );
        refresh();
        return null;
      },
    );
  }

  Future<List<ProjectMemberEntity>> _fetch() async {
    final result = await ref.read(getMyInvitesUseCaseProvider).execute(pageSize: 50);
    return result.fold((failure) => throw failure, (page) => page.items);
  }
}

final myInvitesProvider =
    AsyncNotifierProvider<MyInvitesController, List<ProjectMemberEntity>>(MyInvitesController.new);
