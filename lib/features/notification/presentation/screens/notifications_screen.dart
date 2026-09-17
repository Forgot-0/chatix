import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/notification/domain/entities/notification_entity.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/features/notification/presentation/providers/notification_list_provider.dart';
import 'package:chatix/features/notification/presentation/utils/notification_route_resolver.dart';
import 'package:chatix/features/notification/presentation/utils/notification_timestamp.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// `GET /notifications/` as a screen.
///
/// The list is `PageResult`, whose `has_next` the server does not serialise
/// (api-docs §1.5) — the controller works it out from `total`, `page` and
/// `page_size`, and this screen only asks for the next page when the bottom
/// comes into view.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(notificationBadgeProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationListProvider.notifier).loadMore();
    }
  }

  Future<void> _onTapNotification(NotificationEntity notification) async {
    final l10n = AppLocalizations.of(context);
    final route = resolveNotificationRoute(notification);

    final failure = await ref
        .read(notificationListProvider.notifier)
        .markAsRead(notification.id);

    if (!mounted) return;

    if (failure != null) {
      AppSnackbar.quiet(
        context,
        friendlyFailureMessage(failure, fallback: l10n.errorOccurred),
      );
    }

    if (route != null && mounted) {
      context.push(route);
    }
  }

  Future<void> _onMarkAllAsRead() async {
    final l10n = AppLocalizations.of(context);

    final result = await ref
        .read(notificationListProvider.notifier)
        .markAllAsRead();
    if (!mounted) return;

    result.match(
      (failure) => AppSnackbar.quiet(
        context,
        friendlyFailureMessage(failure, fallback: l10n.errorOccurred),
      ),
      // `PATCH /notifications/read_all/` answers with a bare number, not an
      // object (api-docs §7.4) — it is how many rows it touched, and saying
      // so is the whole confirmation.
      (count) => AppSnackbar.quiet(context, l10n.notificationsMarkedRead(count)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final listState = ref.watch(notificationListProvider);
    final unreadCount = ref.watch(notificationBadgeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          TextButton(
            onPressed: unreadCount == 0 ? null : _onMarkAllAsRead,
            child: Text(l10n.readAll),
          ),
          PopupMenuButton<bool?>(
            tooltip: l10n.filter,
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => ref
                .read(notificationListProvider.notifier)
                .setFilter(isRead: value),
            itemBuilder: (context) => [
              PopupMenuItem<bool?>(value: null, child: Text(l10n.filterAll)),
              PopupMenuItem<bool?>(
                value: false,
                child: Text(l10n.filterUnread),
              ),
              PopupMenuItem<bool?>(value: true, child: Text(l10n.filterRead)),
            ],
          ),
        ],
        bottom: unreadCount == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: _UnreadStrip(count: unreadCount),
              ),
      ),
      body: listState.when(
        loading: () => const AppListSkeleton(hasTrailing: true),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: l10n.notificationsLoadFailed,
          onRetry: () => ref.read(notificationListProvider.notifier).refresh(),
        ),
        data: (state) => RefreshIndicator(
          onRefresh: () =>
              ref.read(notificationListProvider.notifier).refresh(),
          child: state.items.isEmpty
              ? _EmptyState(filter: state.isReadFilter)
              : ListView.separated(
                  key: const PageStorageKey<String>('notifications-list'),
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.x2,
                  ),
                  itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.x1),
                  itemBuilder: (context, index) {
                    if (index >= state.items.length) {
                      return const AppLoadMoreIndicator();
                    }
                    final notification = state.items[index];
                    return _NotificationTile(
                      notification: notification,
                      onTap: () => _onTapNotification(notification),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// How many are unread, under the title, so the "read all" button next to it
/// has a number to mean something against.
class _UnreadStrip extends StatelessWidget {
  const _UnreadStrip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          0,
          AppSpacing.x4,
          AppSpacing.x2,
        ),
        child: Text(
          AppLocalizations.of(context).unreadNotificationsCount(count),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.filter});

  /// `null` for "all", otherwise the read flag the list is filtered by.
  final bool? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return AppEmptyState(
      icon: switch (filter) {
        null => Icons.notifications_none_outlined,
        _ => Icons.filter_list_off,
      },
      title: switch (filter) {
        null => l10n.notificationsEmptyTitle,
        false => l10n.notificationsEmptyUnread,
        true => l10n.notificationsEmptyRead,
      },
      message: switch (filter) {
        null => l10n.notificationsEmptyMessage,
        _ => l10n.notificationsEmptyFilterHint,
      },
      action: filter == null
          ? null
          : TextButton(
              onPressed: () =>
                  ref.read(notificationListProvider.notifier).setFilter(),
              child: Text(l10n.showAll),
            ),
    );
  }
}

/// One row.
///
/// Unread is carried by three things at once — a tinted card, a heavier title
/// and a dot — because a tint alone does not survive a high-contrast theme and
/// a dot alone is easy to miss in a long list.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationEntity notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final isUnread = !notification.isRead;
    final message = notification.message?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
      child: Material(
        color: isUnread
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isUnread
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  child: Icon(
                    _iconFor(notification.type),
                    size: 20,
                    color: isUnread ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              margin: const EdgeInsetsDirectional.only(
                                start: AppSpacing.x2,
                              ),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      if (message != null && message.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.x1),
                      Row(
                        children: [
                          Text(
                            formatNotificationTimestamp(
                              notification.createdAt,
                              l10n,
                              MaterialLocalizations.of(context),
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          if (hasNotificationDestination(notification))
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.chat:
        return Icons.chat_bubble_outline;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }
}
