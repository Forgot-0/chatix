import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/features/notification/domain/entities/notification_entity.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/features/notification/presentation/providers/notification_list_provider.dart';
import 'package:chatix/features/notification/presentation/utils/notification_route_resolver.dart';
import 'package:chatix/core/error/failure_messages.dart';

/// `GET /notifications/` 🔒 (api-docs §8.2) — the notification inbox.
///
/// ⚠️ **Page-based** pagination (api-docs §1.5), unlike the chat list's
/// cursor scheme (§1.6): there is a real page number and a real total, and
/// `hasNext` is computed by `PageResult` rather than sent by the server.
///
/// Nothing here is realtime. The backend pushes no notification events over
/// the WebSocket (api-docs §7), so the list is only ever as fresh as the last
/// open, pull-to-refresh or badge poll.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Opening the inbox is one of the few reliable moments to re-sync the
    // badge — see NotificationBadgeController for why it can't be event
    // driven.
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
    // Pre-fetch 200 px early so the next page is usually already there.
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationListProvider.notifier).loadMore();
    }
  }

  Future<void> _onTapNotification(NotificationEntity notification) async {
    // Resolve the destination *before* awaiting anything — the entity in
    // state is replaced by the optimistic read-flag update below, and the
    // route must not depend on which instance we happen to hold afterwards.
    final route = resolveNotificationRoute(notification);

    final failure = await ref
        .read(notificationListProvider.notifier)
        .markAsRead(notification.id);

    if (!mounted) return;

    if (failure != null) {
      // The row has already rolled back by now; tell the user why it
      // un-greyed itself, then still navigate — failing to mark it read is
      // no reason to refuse to open what it's about.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    }

    if (route != null && mounted) {
      context.push(route);
    }
  }

  Future<void> _onMarkAllAsRead() async {
    final result = await ref.read(notificationListProvider.notifier).markAllAsRead();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    result.match(
      (failure) => messenger.showSnackBar(SnackBar(content: Text(failure.message))),
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
        title: const Text('Notifications'),
        actions: [
          // `PATCH /notifications/read_all/` (api-docs §8.4). Disabled when
          // the badge says there's nothing unread — the call would succeed
          // and return 0, which is just a wasted request.
          TextButton(
            onPressed: unreadCount == 0 ? null : _onMarkAllAsRead,
            child: const Text('Read all'),
          ),
          PopupMenuButton<bool?>(
            tooltip: 'Filter',
            icon: const Icon(Icons.filter_list),
            onSelected: (value) =>
                ref.read(notificationListProvider.notifier).setFilter(isRead: value),
            itemBuilder: (context) => const [
              PopupMenuItem<bool?>(value: null, child: Text('All')),
              PopupMenuItem<bool?>(value: false, child: Text('Unread only')),
              PopupMenuItem<bool?>(value: true, child: Text('Read only')),
            ],
          ),
        ],
      ),
      body: listState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: friendlyFailureMessage(error, fallback: 'Failed to load notifications'),
          onRetry: () => ref.read(notificationListProvider.notifier).refresh(),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(notificationListProvider.notifier).refresh(),
              // A scrollable is required for pull-to-refresh to work on an
              // otherwise empty page.
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No notifications yet')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(notificationListProvider.notifier).refresh(),
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
      // Unread rows are tinted rather than bolded alone — a weight change is
      // easy to miss in a list where every title is short.
      tileColor: isUnread ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25) : null,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Icon(_iconFor(notification.type), size: 20),
      ),
      title: Text(
        notification.title,
        style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `message` is nullable (api-docs §8.2) — a title-only
          // notification renders without an empty gap.
          if (notification.message != null && notification.message!.isNotEmpty)
            Text(notification.message!, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(_formatTimestamp(notification.createdAt), style: theme.textTheme.bodySmall),
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
      case NotificationType.project:
        return Icons.work_outline;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  /// Relative for anything recent, absolute once "3 days ago" stops being
  /// more useful than a date.
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
