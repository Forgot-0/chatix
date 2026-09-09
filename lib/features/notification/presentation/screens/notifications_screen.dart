import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/features/notification/domain/entities/notification_entity.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/features/notification/presentation/providers/notification_list_provider.dart';
import 'package:chatix/features/notification/presentation/utils/notification_route_resolver.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

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
    final route = resolveNotificationRoute(notification);

    final failure = await ref
        .read(notificationListProvider.notifier)
        .markAsRead(notification.id);

    if (!mounted) return;

    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }

    if (route != null && mounted) {
      context.push(route);
    }
  }

  Future<void> _onMarkAllAsRead() async {
    final result = await ref
        .read(notificationListProvider.notifier)
        .markAllAsRead();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    result.match(
      (failure) =>
          messenger.showSnackBar(SnackBar(content: Text(failure.message))),
      (count) => messenger.showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'No unread notifications'
                : 'Marked $count notification${count == 1 ? '' : 's'} as read',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(notificationListProvider);
    final unreadCount = ref.watch(notificationBadgeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).notifications),
        actions: [
          TextButton(
            onPressed: unreadCount == 0 ? null : _onMarkAllAsRead,
            child: Text(AppLocalizations.of(context).readAll),
          ),
          PopupMenuButton<bool?>(
            tooltip: AppLocalizations.of(context).filter,
            icon: Icon(Icons.filter_list),
            onSelected: (value) => ref
                .read(notificationListProvider.notifier)
                .setFilter(isRead: value),
            itemBuilder: (context) => [
              PopupMenuItem<bool?>(
                value: null,
                child: Text(AppLocalizations.of(context).filterAll),
              ),
              PopupMenuItem<bool?>(
                value: false,
                child: Text(AppLocalizations.of(context).filterUnread),
              ),
              PopupMenuItem<bool?>(
                value: true,
                child: Text(AppLocalizations.of(context).filterRead),
              ),
            ],
          ),
        ],
      ),
      body: listState.when(
        loading: () => const AppListSkeleton(hasTrailing: true),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: AppLocalizations.of(context).notificationsLoadFailed,
          onRetry: () => ref.read(notificationListProvider.notifier).refresh(),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationListProvider.notifier).refresh(),
              child: AppEmptyState(
                icon: switch (state.isReadFilter) {
                  null => Icons.notifications_none_outlined,
                  _ => Icons.filter_list_off,
                },
                title: switch (state.isReadFilter) {
                  null => 'No notifications yet',
                  false => 'Nothing unread',
                  true => 'Nothing read yet',
                },
                message: switch (state.isReadFilter) {
                  null =>
                    "We'll let you know about invites, applications and "
                        'messages here.',
                  _ => 'Switch the filter to “All” to see everything.',
                },
                action: state.isReadFilter == null
                    ? null
                    : TextButton(
                        onPressed: () => ref
                            .read(notificationListProvider.notifier)
                            .setFilter(),
                        child: Text(AppLocalizations.of(context).showAll),
                      ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(notificationListProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
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
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationEntity notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return ListTile(
      onTap: onTap,
      tileColor: isUnread
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
          : null,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Icon(_iconFor(notification.type), size: 20),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.message != null && notification.message!.isNotEmpty)
            Text(
              notification.message!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            _formatTimestamp(notification.createdAt),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      trailing: hasNotificationDestination(notification)
          ? const Icon(Icons.chevron_right)
          : null,
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

  static String _formatTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    final local = timestamp.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year}';
  }
}
