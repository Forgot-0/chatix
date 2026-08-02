import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';

/// The persistent frame of the signed-in app: whatever the current tab is
/// showing, plus a bottom navigation bar that is always there.
///
/// ### What it replaces
///
/// Until now the landing screen was a "home" dashboard of buttons that pushed
/// onto a single flat stack — reaching notifications meant going through home,
/// and coming back from a chat meant popping to wherever you happened to have
/// come from. Four tabs make each area a top-level destination that is one tap
/// away from any other, and each keeps its own scroll position and navigation
/// stack.
///
/// ### The four destinations
///
/// Chats, Projects, Notifications, Profile. Everything else — a conversation,
/// a project's detail, a position, someone else's profile, settings — is a
/// *flat* route pushed **over** this shell rather than a fifth tab, because
/// those are places you go into and come back out of, and burying a
/// full-screen conversation under a tab bar that could switch out from under
/// it is how you lose a half-typed message.
///
/// ### `StatefulShellRoute`, not a plain `ShellRoute`
///
/// A plain `ShellRoute` gives all its children one shared `Navigator`:
/// switching tabs would *replace* the branch, so returning to Chats after a
/// detour through Projects would rebuild the list from scratch, refetch it,
/// and dump the user back at the top. `StatefulShellRoute.indexedStack` (a
/// member of the same `ShellRouteBase` family, added for exactly this case)
/// keeps one `Navigator` per branch alive in an `IndexedStack`, which is what
/// a bottom navigation bar is expected to feel like.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  /// The branch container built by `StatefulShellRoute.indexedStack` — it
  /// both renders the active branch and exposes [StatefulNavigationShell.goBranch].
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // api-docs §8.3. Poll-driven (there is no realtime channel for it), and
    // mounting anything that watches it is what starts the polling — so the
    // shell keeps the badge live for the whole session rather than only while
    // the notifications tab happens to be on screen.
    final unreadCount = ref.watch(notificationBadgeProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _onDestinationSelected(index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          const NavigationDestination(
            icon: Icon(Icons.workspaces_outline),
            selectedIcon: Icon(Icons.workspaces),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Badge(
              // Hidden rather than removed when the count is zero, so the
              // icon doesn't shift as the badge appears and disappears.
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.notifications),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  /// Switches branch — and, when the already-selected tab is tapped again,
  /// pops that branch back to its root.
  ///
  /// That second behaviour is the platform convention on both iOS and
  /// Android: tapping "Chats" while three screens deep inside a conversation
  /// is how people expect to get back to the list. `initialLocation: true`
  /// only has that effect for the current branch; for a different branch it
  /// would throw away the stack the user left behind, which is precisely what
  /// the stateful shell exists to preserve.
  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
