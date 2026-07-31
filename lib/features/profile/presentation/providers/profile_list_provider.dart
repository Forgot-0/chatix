import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

const _pageSize = 20;

/// `GET /profiles/` list state — accumulated [items] across pages (for
/// infinite scroll) plus enough of the last fetched page and the active
/// filters to fetch the next page or re-run the same search.
class ProfileListState extends Equatable {
  final List<ProfileEntity> items;
  final int page;
  final bool hasNext;
  final bool isLoadingMore;
  final String? username;
  final String? displayName;
  final List<String>? skills;
  final String? sort;

  const ProfileListState({
    this.items = const [],
    this.page = 1,
    this.hasNext = false,
    this.isLoadingMore = false,
    this.username,
    this.displayName,
    this.skills,
    this.sort,
  });

  ProfileListState copyWith({
    List<ProfileEntity>? items,
    int? page,
    bool? hasNext,
    bool? isLoadingMore,
  }) {
    return ProfileListState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      username: username,
      displayName: displayName,
      skills: skills,
      sort: sort,
    );
  }

  @override
  List<Object?> get props => [items, page, hasNext, isLoadingMore, username, displayName, skills, sort];
}

/// Drives `ProfilesListScreen`: initial load on [build], [search] to
/// replace the current filters and reset to page 1, [loadMore] to append
/// the next page (e.g. on scroll-to-bottom), and [refresh] to re-run the
/// current search from page 1 (e.g. pull-to-refresh).
class ProfileListController extends AsyncNotifier<ProfileListState> {
  @override
  Future<ProfileListState> build() {
    return _fetchFirstPage();
  }

  Future<void> search({String? username, String? displayName, List<String>? skills, String? sort}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchFirstPage(username: username, displayName: displayName, skills: skills, sort: sort),
    );
  }

  Future<void> refresh() async {
    final previous = state.value ?? const ProfileListState();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchFirstPage(
        username: previous.username,
        displayName: previous.displayName,
        skills: previous.skills,
        sort: previous.sort,
      ),
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final result = await ref.read(getProfilesUseCaseProvider).execute(
      username: current.username,
      displayName: current.displayName,
      skills: current.skills,
      page: current.page + 1,
      pageSize: _pageSize,
      sort: current.sort,
    );

    state = result.fold(
      (failure) => AsyncValue.error(failure, StackTrace.current),
      (page) => AsyncValue.data(
        current.copyWith(
          items: [...current.items, ...page.items],
          page: page.page,
          hasNext: page.hasNext,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<ProfileListState> _fetchFirstPage({
    String? username,
    String? displayName,
    List<String>? skills,
    String? sort,
  }) async {
    final result = await ref.read(getProfilesUseCaseProvider).execute(
      username: username,
      displayName: displayName,
      skills: skills,
      page: 1,
      pageSize: _pageSize,
      sort: sort,
    );

    return result.fold((failure) => throw failure, (page) {
      return ProfileListState(
        items: page.items,
        page: page.page,
        hasNext: page.hasNext,
        username: username,
        displayName: displayName,
        skills: skills,
        sort: sort,
      );
    });
  }
}

final profileListProvider = AsyncNotifierProvider<ProfileListController, ProfileListState>(
  ProfileListController.new,
);
