import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_page_transitions.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The four places the app is ever "in": chats, contacts, alerts, settings.
///
/// The shell measures the window once and hands the answer down through
/// [AppLayoutScope] — a bottom bar on a phone, a rail from tablet width up, and
/// from [AppBreakpoints.expanded] a rail plus the two-pane chats layout that
/// `ChatsPaneShell` builds. The branches themselves live in an `IndexedStack`,
/// so every tab keeps its navigation stack and its scroll position while the
/// others are on screen.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mode = AppBreakpoints.modeFor(constraints.maxWidth);

        return AppLayoutScope(
          mode: mode,
          child: _AppShellScaffold(
            navigationShell: navigationShell,
            mode: mode,
          ),
        );
      },
    );
  }
}

class _AppShellScaffold extends ConsumerWidget {
  const _AppShellScaffold({required this.navigationShell, required this.mode});

  final StatefulNavigationShell navigationShell;
  final AppLayoutMode mode;

  static const int _chatsBranch = 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The chats badge counts unread *messages*, summed over the chat list —
    // the notifications badge below is a different number and stays separate.
    // Watching it here also keeps the chat list (and its socket subscription)
    // alive while the user is on another tab, which is what makes the count
    // move in real time.
    final unreadChats = ref.watch(
      chatListProvider.select((state) => state.value?.totalUnread ?? 0),
    );
    final unreadAlerts = ref.watch(notificationBadgeProvider);

    final destinations = _destinations(
      context,
      unreadChats: unreadChats,
      unreadAlerts: unreadAlerts,
    );

    final body = FadeThroughSwitcher(
      switchKey: navigationShell.currentIndex,
      child: navigationShell,
    );

    if (mode.usesBottomBar) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _goBranch,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: destination.icon,
                selectedIcon: destination.selectedIcon,
                label: destination.label,
                tooltip: destination.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _ShellRail(
            destinations: destinations,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: body),
        ],
      ),
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the tab you are already on returns it to its root, the
      // platform convention on both Android and iOS.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  List<_ShellDestination> _destinations(
    BuildContext context, {
    required int unreadChats,
    required int unreadAlerts,
  }) {
    final l10n = AppLocalizations.of(context);

    return [
      _ShellDestination(
        label: l10n.chats,
        icon: _LongPressableIcon(
          onLongPress: () => _openChatQuickActions(context),
          semanticsHint: l10n.quickActionsHint,
          child: _CountBadge(
            count: unreadChats,
            semanticsLabel: l10n.unreadMessagesCount(unreadChats),
            child: const Icon(Icons.chat_bubble_outline),
          ),
        ),
        selectedIcon: _LongPressableIcon(
          onLongPress: () => _openChatQuickActions(context),
          semanticsHint: l10n.quickActionsHint,
          child: _CountBadge(
            count: unreadChats,
            semanticsLabel: l10n.unreadMessagesCount(unreadChats),
            child: const Icon(Icons.chat_bubble),
          ),
        ),
      ),
      _ShellDestination(
        label: l10n.contacts,
        icon: const Icon(Icons.people_outline),
        selectedIcon: const Icon(Icons.people),
      ),
      _ShellDestination(
        label: l10n.notifications,
        icon: _CountBadge(
          count: unreadAlerts,
          semanticsLabel: l10n.unreadNotificationsCount(unreadAlerts),
          child: const Icon(Icons.notifications_outlined),
        ),
        selectedIcon: _CountBadge(
          count: unreadAlerts,
          semanticsLabel: l10n.unreadNotificationsCount(unreadAlerts),
          child: const Icon(Icons.notifications),
        ),
      ),
      _ShellDestination(
        label: l10n.settings,
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
      ),
    ];
  }

  Future<void> _openChatQuickActions(BuildContext context) async {
    HapticFeedback.selectionClick();

    // A long press is a shortcut, not a navigation: it should not move the
    // user off whatever tab they are on if they dismiss the sheet.
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => const _ChatQuickActionsSheet(),
    );

    if (action == null || !context.mounted) return;

    if (navigationShell.currentIndex != _chatsBranch) {
      navigationShell.goBranch(_chatsBranch);
    }
    if (!context.mounted) return;

    context.push(CreateChatRoute.locationOf(action));
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final Widget icon;
  final Widget selectedIcon;
}

/// The rail, wrapped so it stays usable in a short landscape window.
class _ShellRail extends StatelessWidget {
  const _ShellRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: Text(destination.label),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A badge that disappears at zero and announces itself in words.
class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.semanticsLabel,
    required this.child,
  });

  final int count;
  final String semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Badge(label: Text(count > 99 ? '99+' : '$count'), child: child),
    );
  }
}

/// Adds a long press to a destination without taking its tap away.
///
/// `NavigationBar` and `NavigationRail` handle the tap on an ancestor ink
/// response and register no long-press recogniser of their own, so a detector
/// on the icon claims the long press uncontested and lets every tap through.
class _LongPressableIcon extends StatelessWidget {
  const _LongPressableIcon({
    required this.onLongPress,
    required this.semanticsHint,
    required this.child,
  });

  final VoidCallback onLongPress;
  final String semanticsHint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      onLongPressHint: semanticsHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }
}

class _ChatQuickActionsSheet extends StatelessWidget {
  const _ChatQuickActionsSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: Text(l10n.newDirectChat),
            onTap: () =>
                Navigator.of(context).pop(CreateChatRoute.directType),
          ),
          ListTile(
            leading: const Icon(Icons.group_add_outlined),
            title: Text(l10n.newGroup),
            onTap: () => Navigator.of(context).pop(CreateChatRoute.groupType),
          ),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: Text(l10n.newChannel),
            onTap: () => Navigator.of(context).pop(CreateChatRoute.channelType),
          ),
        ],
      ),
    );
  }
}
