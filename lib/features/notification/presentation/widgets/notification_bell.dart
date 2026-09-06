import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/core/router/app_routes.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationBadgeProvider);

    return IconButton(
      tooltip: unreadCount > 0
          ? '$unreadCount unread notifications'
          : 'Notifications',
      onPressed: onTap ?? () => context.push(NotificationsRoute.location),
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(_badgeLabel(unreadCount)),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }

  static String _badgeLabel(int count) => count > 99 ? '99+' : '$count';
}
