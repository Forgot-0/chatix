import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/notification/domain/entities/notification_entity.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/features/notification/presentation/providers/notification_providers.dart';

const _pageSize = 20;

/// `GET /notifications/` list state — items accumulated across pages, plus
/// the last page number and the active `is_read` filter so the next page (or
/// a re-run of the same query) can be built.
///
/// Mirrors `ProfileListState`: same page-based scheme (api-docs §1.5), same
/// `hasNext` computed client-side by `PageResult`.
class NotificationListState extends Equatable {
  final List<NotificationEntity> items;
  final int page;
  final bool hasNext;
  final bool isLoadingMore;

  /// `null` = all, `false` = unread only, `true` = read only.
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
  List<Object?> get props => [items, page, hasNext, isLoadingMore, isReadFilter];
}

/// Drives `NotificationsScreen`.
///
/// Read-state changes are applied **optimistically**: the endpoints return an
/// empty body (api-docs §8.4), so there is nothing to merge back, and a
/// refetch just to grey out one row would throw away the user's scroll
/// position. On failure the local change is rolled back and the error is
/// surfaced by the caller, not by replacing the whole list with an error
/// screen.
class NotificationListController extends AsyncNotifier<NotificationListState> {
  @override
  Future<NotificationListState> build() {
    return _fetchFirstPage();
  }

  /// Re-runs the current query from page 1 (pull-to-refresh, or returning to
  /// the screen). Also re-syncs the badge, since this is the moment the user
  /// is actually looking at the inbox.
  Future<void> refresh() async {
    final filter = state.value?.isReadFilter;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchFirstPage(isRead: filter));
    unawaited(ref.read(notificationBadgeProvider.notifier).refresh());
  }

  /// Switches between "all" and "unread only" and resets to page 1.
  Future<void> setFilter({bool? isRead}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchFirstPage(isRead: isRead));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final result = await ref.read(getNotificationsUseCaseProvider).execute(
      isRead: current.isReadFilter,
      page: current.page + 1,
      pageSize: _pageSize,
    );

    state = result.fold(
      // A failed *additional* page must not wipe the pages already on
      // screen — drop back to the previous state and let the user retry by
      // scrolling again.
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

  /// Marks one notification read (api-docs §8.4) and updates the row and the
  /// badge in place.
  ///
  /// Returns the [Failure] when the server rejected it (`403
  /// NOTIFICATION_ACCESS_DENIED`, `404 NOT_FOUND_NOTIFICATION`, api-docs
  /// §2.8), or `null` on success — the screen decides whether that is worth a
  /// snackbar. Already-read notifications are a no-op, so tapping a read item
  /// costs no request.
  Future<Failure?> markAsRead(int notificationId) async {
    final current = state.value;
    if (current == null) return null;

    final index = current.items.indexWhere((n) => n.id == notificationId);
    if (index == -1) return null;
    if (current.items[index].isRead) return null;

    // Optimistic: flip the row now.
    state = AsyncValue.data(
      current.copyWith(items: _withReadFlag(current.items, index, true)),
    );
    ref.read(notificationBadgeProvider.notifier).decrementBy(1);

    final result = await ref.read(markAsReadUseCaseProvider).execute(notificationId);

    return result.match(
      (failure) {
        // Roll back — both the row and the badge.
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
      },
      (_) => null,
    );
  }

  /// `PATCH /notifications/read_all/` (api-docs §8.4).
  ///
  /// Returns `Right(count)` — the bare number the server replies with, worth
  /// echoing back to the user ("7 marked as read"), and `0` meaning there was
  /// nothing to do.
  Future<Either<Failure, int>> markAllAsRead() async {
    final result = await ref.read(markAllAsReadUseCaseProvider).execute();

    return result.match(
      (failure) => Left(failure),
      (count) {
        final current = state.value;
        if (current != null) {
          if (current.isReadFilter == false) {
            // Viewing "unread only": every visible row just left the filter,
            // so refetch rather than showing a list that contradicts itself.
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
      },
    );
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
    final result = await ref.read(getNotificationsUseCaseProvider).execute(
      isRead: isRead,
      page: 1,
      pageSize: _pageSize,
    );

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
