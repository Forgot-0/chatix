import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The way into the notifications list, with how many are unread on it.
///
/// Notifications are not a tab: they are a page over whatever asked for
/// them, so the bell pushes `/notifications` rather than switching to it.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unreadCount = ref.watch(notificationBadgeProvider);

    return IconButton(
      tooltip: unreadCount > 0
          ? l10n.unreadNotificationsCount(unreadCount)
          : l10n.notifications,
      onPressed: onTap ?? () => context.push(NotificationsRoute.location),
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(badgeLabel(unreadCount)),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }

  /// What a count badge says: the number, or "99+" past the room it has.
  static String badgeLabel(int count) => count > 99 ? '99+' : '$count';
}
