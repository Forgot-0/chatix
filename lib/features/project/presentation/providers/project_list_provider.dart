import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/presentation/providers/project_providers.dart';

const _pageSize = 20;

/// `GET /projects/` list state — accumulated [items] across pages plus the
/// active [name]/[tags] filters so the next page or a re-run uses the same
/// query. Mirrors `ProfileListState`.
class ProjectListState extends Equatable {
  final List<ProjectEntity> items;
  final int page;
  final bool hasNext;
  final bool isLoadingMore;
  final String? name;
  final List<String>? tags;
  final String? sort;

  const ProjectListState({
    this.items = const [],
    this.page = 1,
    this.hasNext = false,
    this.isLoadingMore = false,
    this.name,
    this.tags,
    this.sort,
  });

  ProjectListState copyWith({
    List<ProjectEntity>? items,
    int? page,
    bool? hasNext,
    bool? isLoadingMore,
  }) {
    return ProjectListState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      name: name,
      tags: tags,
      sort: sort,
    );
  }

  @override
  List<Object?> get props => [items, page, hasNext, isLoadingMore, name, tags, sort];
}

/// Drives `ProjectsListScreen`: [search] to replace filters and reset to page
/// 1, [loadMore] to append the next page, [refresh] to re-run the current
/// search. ⚠️ `/projects/` requires auth (api-docs §5) — unlike the profiles
/// list, there is no public read path here.
class ProjectListController extends AsyncNotifier<ProjectListState> {
  @override
  Future<ProjectListState> build() => _fetchFirstPage();

  Future<void> search({String? name, List<String>? tags, String? sort}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchFirstPage(name: name, tags: tags, sort: sort));
  }

  Future<void> refresh() async {
    final prev = state.value ?? const ProjectListState();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchFirstPage(name: prev.name, tags: prev.tags, sort: prev.sort),
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final result = await ref.read(getProjectsUseCaseProvider).execute(
      name: current.name,
      tags: current.tags,
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

  Future<ProjectListState> _fetchFirstPage({String? name, List<String>? tags, String? sort}) async {
    final result = await ref.read(getProjectsUseCaseProvider).execute(
      name: name,
      tags: tags,
      page: 1,
      pageSize: _pageSize,
      sort: sort,
    );
    return result.fold((failure) => throw failure, (page) {
      return ProjectListState(
        items: page.items,
        page: page.page,
        hasNext: page.hasNext,
        name: name,
        tags: tags,
        sort: sort,
      );
    });
  }
}

final projectListProvider =
    AsyncNotifierProvider<ProjectListController, ProjectListState>(ProjectListController.new);
