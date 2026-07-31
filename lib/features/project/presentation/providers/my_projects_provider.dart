import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/presentation/providers/project_providers.dart';

const _pageSize = 20;

/// State for `GET /projects/my/`. [total] is surfaced so the "create project"
/// button can be pre-disabled once the user hits the 3-project limit
/// (api-docs §5.1) — the server still does the authoritative check.
class MyProjectsState extends Equatable {
  final List<ProjectEntity> items;
  final int total;
  final int page;
  final bool hasNext;
  final bool isLoadingMore;

  const MyProjectsState({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.hasNext = false,
    this.isLoadingMore = false,
  });

  MyProjectsState copyWith({
    List<ProjectEntity>? items,
    int? total,
    int? page,
    bool? hasNext,
    bool? isLoadingMore,
  }) {
    return MyProjectsState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [items, total, page, hasNext, isLoadingMore];
}

class MyProjectsController extends AsyncNotifier<MyProjectsState> {
  @override
  Future<MyProjectsState> build() => _fetchFirstPage();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchFirstPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.isLoadingMore) return;
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    final result = await ref
        .read(getMyProjectsUseCaseProvider)
        .execute(page: current.page + 1, pageSize: _pageSize);
    state = result.fold(
      (failure) => AsyncValue.error(failure, StackTrace.current),
      (page) => AsyncValue.data(
        current.copyWith(
          items: [...current.items, ...page.items],
          total: page.total,
          page: page.page,
          hasNext: page.hasNext,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<MyProjectsState> _fetchFirstPage() async {
    final result =
        await ref.read(getMyProjectsUseCaseProvider).execute(page: 1, pageSize: _pageSize);
    return result.fold((failure) => throw failure, (page) {
      return MyProjectsState(
        items: page.items,
        total: page.total,
        page: page.page,
        hasNext: page.hasNext,
      );
    });
  }
}

final myProjectsProvider =
    AsyncNotifierProvider<MyProjectsController, MyProjectsState>(MyProjectsController.new);
