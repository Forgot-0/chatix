import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';

/// App-bar bell with the unread count (api-docs §8.3), opening
/// `NotificationsScreen`.
///
/// The count comes from [notificationBadgeProvider], which polls — there is
/// no realtime notification channel (api-docs §7). Mounting this widget is
/// enough to start that polling, and it stops when the last bell is disposed
/// or the user signs out.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.onTap});

  /// Overrides the default navigation to the notifications screen.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationBadgeProvider);

    return IconButton(
      tooltip: unreadCount > 0
          ? '$unreadCount unread notifications'
          : 'Notifications',
      onPressed: onTap ?? () => context.push(AppConstants.notificationsRoute),
      icon: Badge(
        // `isLabelVisible: false` keeps the icon's layout identical whether
        // or not there's a badge, so the app bar doesn't shift when the
        // count drops to zero.
        isLabelVisible: unreadCount > 0,
        label: Text(_badgeLabel(unreadCount)),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }

  /// Caps the label at "99+". An exact count past ~99 is both unreadable at
  /// badge size and useless — the user is going to open the list either way.
  static String _badgeLabel(int count) => count > 99 ? '99+' : '$count';
}
