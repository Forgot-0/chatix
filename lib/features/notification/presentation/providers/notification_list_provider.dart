import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/notification/domain/entities/notification_entity.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/features/notification/presentation/providers/notification_providers.dart';

const _pageSize = 20;

class NotificationListState extends Equatable {
  final List<NotificationEntity> items;
  final int page;
  final bool hasNext;
  final bool isLoadingMore;

  final bool? isReadFilter;

  const NotificationListState({
    this.items = const [],
    this.page = 1,
    this.hasNext = false,
    this.isLoadingMore = false,
    this.isReadFilter,
  });

  NotificationListState copyWith({
    List<NotificationEntity>? items,
    int? page,
    bool? hasNext,
    bool? isLoadingMore,
  }) {
    return NotificationListState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isReadFilter: isReadFilter,
    );
  }

  @override
  List<Object?> get props => [
    items,
    page,
    hasNext,
    isLoadingMore,
    isReadFilter,
  ];
}

class NotificationListController extends AsyncNotifier<NotificationListState> {
  @override
  Future<NotificationListState> build() {
    return _fetchFirstPage();
  }

  Future<void> refresh() async {
    final filter = state.value?.isReadFilter;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchFirstPage(isRead: filter));
    unawaited(ref.read(notificationBadgeProvider.notifier).refresh());
  }

  Future<void> setFilter({bool? isRead}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchFirstPage(isRead: isRead));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final result = await ref
        .read(getNotificationsUseCaseProvider)
        .execute(
          isRead: current.isReadFilter,
          page: current.page + 1,
          pageSize: _pageSize,
        );

    state = result.fold(
      (_) => AsyncValue.data(current.copyWith(isLoadingMore: false)),
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

  Future<Failure?> markAsRead(int notificationId) async {
    final current = state.value;
    if (current == null) return null;

    final index = current.items.indexWhere((n) => n.id == notificationId);
    if (index == -1) return null;
    if (current.items[index].isRead) return null;

    state = AsyncValue.data(
      current.copyWith(items: _withReadFlag(current.items, index, true)),
    );
    ref.read(notificationBadgeProvider.notifier).decrementBy(1);

    final result = await ref
        .read(markAsReadUseCaseProvider)
        .execute(notificationId);

    return result.match((failure) {
      final latest = state.value;
      if (latest != null) {
        final i = latest.items.indexWhere((n) => n.id == notificationId);
        if (i != -1) {
          state = AsyncValue.data(
            latest.copyWith(items: _withReadFlag(latest.items, i, false)),
          );
        }
      }
      unawaited(ref.read(notificationBadgeProvider.notifier).refresh());
      return failure;
    }, (_) => null);
  }

  Future<Either<Failure, int>> markAllAsRead() async {
    final result = await ref.read(markAllAsReadUseCaseProvider).execute();

    return result.match((failure) => Left(failure), (count) {
      final current = state.value;
      if (current != null) {
        if (current.isReadFilter == false) {
          unawaited(refresh());
        } else {
          state = AsyncValue.data(
            current.copyWith(
              items: [
                for (final n in current.items)
                  n.isRead ? n : n.copyWith(isRead: true),
              ],
            ),
          );
        }
      }
      ref.read(notificationBadgeProvider.notifier).clear();
      return Right(count);
    });
  }

  static List<NotificationEntity> _withReadFlag(
    List<NotificationEntity> items,
    int index,
    bool isRead,
  ) {
    final copy = [...items];
    copy[index] = copy[index].copyWith(isRead: isRead);
    return copy;
  }

  Future<NotificationListState> _fetchFirstPage({bool? isRead}) async {
    final result = await ref
        .read(getNotificationsUseCaseProvider)
        .execute(isRead: isRead, page: 1, pageSize: _pageSize);

    return result.fold((failure) => throw failure, (page) {
      return NotificationListState(
        items: page.items,
        page: page.page,
        hasNext: page.hasNext,
        isReadFilter: isRead,
      );
    });
  }
}

final notificationListProvider =
    AsyncNotifierProvider<NotificationListController, NotificationListState>(
      NotificationListController.new,
    );
