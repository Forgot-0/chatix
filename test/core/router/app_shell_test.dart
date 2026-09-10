import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/router/app_shell.dart';
import 'package:chatix/core/router/chats_pane_shell.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@example.com');
}

class _FakeChatListController extends ChatListController {
  _FakeChatListController(this._state);

  final ChatListState _state;

  @override
  Future<ChatListState> build() async => _state;
}

class _FakeNotificationBadge extends NotificationBadgeController {
  _FakeNotificationBadge(this._count);

  final int _count;

  @override
  int build() => _count;
}

/// Stands in for the branch screens the shell is not itself responsible for.
class _Probe extends StatelessWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

void main() {
  ChatEntity chat(String id, {required int unread, String? name}) => ChatEntity(
    id: id,
    seqCounter: 10,
    lastActivityAt: DateTime.utc(2026, 1, 1),
    type: ChatType.group,
    name: name ?? 'Chat $id',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: 3,
    unreadCount: unread,
  );

  GoRouter buildRouter() {
    // Mirrors the real router: the create/search forms take over the whole
    // screen instead of landing in a pane.
    final rootNavigatorKey = GlobalKey<NavigatorState>();

    return GoRouter(
      initialLocation: ChatsRoute.location,
      navigatorKey: rootNavigatorKey,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                ShellRoute(
                  builder: (context, state, child) => ChatsPaneShell(
                    selectedChatId: ChatDetailRoute.idFrom(state),
                    child: child,
                  ),
                  routes: [
                    GoRoute(
                      path: ChatsRoute.path,
                      builder: (_, _) => const ChatsListPane(),
                      routes: [
                        GoRoute(
                          path: CreateChatRoute.path,
                          parentNavigatorKey: rootNavigatorKey,
                          builder: (_, state) => _Probe(
                            'create:${CreateChatRoute.typeFrom(state) ?? 'any'}',
                          ),
                        ),
                        GoRoute(
                          path: ChatDetailRoute.path,
                          builder: (_, state) =>
                              _Probe('chat:${ChatDetailRoute.idFrom(state)}'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: ProfilesRoute.path,
                  builder: (_, _) => const _Probe('contacts-branch'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: NotificationsRoute.path,
                  builder: (_, _) => const _Probe('alerts-branch'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: SettingsRoute.path,
                  builder: (_, _) => const _Probe('settings-branch'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    required Size size,
    List<ChatEntity> chats = const [],
    int alerts = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthController.new),
          chatListProvider.overrideWith(
            () => _FakeChatListController(ChatListState(items: chats)),
          ),
          notificationBadgeProvider.overrideWith(
            () => _FakeNotificationBadge(alerts),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return router;
  }

  const phone = Size(400, 800);
  const tabletPortrait = Size(768, 1024);
  const desktop = Size(1200, 900);

  group('the shell', () {
    testWidgets('offers four destinations, in order', (tester) async {
      await pumpShell(tester, size: phone);

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        bar.destinations
            .cast<NavigationDestination>()
            .map((destination) => destination.label),
        ['Chats', 'Contacts', 'Notifications', 'Settings'],
      );
    });

    testWidgets('badges chats with the unread sum, not the alert count', (
      tester,
    ) async {
      await pumpShell(
        tester,
        size: phone,
        chats: [
          chat('a', unread: 3),
          chat('b', unread: 4),
          chat('c', unread: 0),
        ],
        alerts: 2,
      );

      // 3 + 4 + 0 — the chats badge counts messages, the alerts badge counts
      // notifications, and the two must not be the same number.
      expect(find.text('7'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('shows no badge when everything is read', (tester) async {
      await pumpShell(
        tester,
        size: phone,
        chats: [chat('a', unread: 0)],
        alerts: 0,
      );

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('caps a runaway count at 99+', (tester) async {
      await pumpShell(
        tester,
        size: phone,
        chats: [chat('a', unread: 120)],
      );

      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('adaptive chrome', () {
    testWidgets('a phone gets the bottom bar', (tester) async {
      await pumpShell(tester, size: phone);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('a tablet in portrait gets the rail, still one pane', (
      tester,
    ) async {
      await pumpShell(tester, size: tabletPortrait);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NoChatSelectedPane), findsNothing);
    });

    testWidgets('a desktop window gets the rail and the second pane', (
      tester,
    ) async {
      await pumpShell(tester, size: desktop);

      expect(find.byType(NavigationRail), findsOneWidget);
      // The list on the left, the placeholder on the right.
      expect(find.byType(ChatsListScreen), findsOneWidget);
      expect(find.byType(NoChatSelectedPane), findsOneWidget);
    });
  });

  group('two panes', () {
    testWidgets('an open chat sits beside the list, not over it', (
      tester,
    ) async {
      final router = await pumpShell(
        tester,
        size: desktop,
        chats: [chat('a', unread: 0), chat('b', unread: 0)],
      );

      router.go(const ChatDetailRoute('b').location);
      await tester.pumpAndSettle();

      expect(find.byType(ChatsListScreen), findsOneWidget);
      expect(find.text('chat:b'), findsOneWidget);
      expect(find.byType(NoChatSelectedPane), findsNothing);
    });

    testWidgets('the list marks the chat that is open', (tester) async {
      final router = await pumpShell(
        tester,
        size: desktop,
        chats: [chat('a', unread: 0), chat('b', unread: 0)],
      );

      router.go(const ChatDetailRoute('b').location);
      await tester.pumpAndSettle();

      final tiles = tester
          .widgetList<ChatListTile>(find.byType(ChatListTile))
          .toList();
      expect(tiles.map((tile) => tile.isSelected), [false, true]);
    });

    testWidgets('the open chat survives a rotation into one pane and back', (
      tester,
    ) async {
      final router = await pumpShell(
        tester,
        size: desktop,
        chats: [chat('a', unread: 0), chat('b', unread: 0)],
      );

      router.go(const ChatDetailRoute('b').location);
      await tester.pumpAndSettle();

      // Rotate to a phone-sized window: one pane, same chat.
      tester.view.physicalSize = phone;
      await tester.pumpAndSettle();

      expect(find.text('chat:b'), findsOneWidget);
      expect(find.byType(ChatsListScreen), findsNothing);

      // And back: the chat is still the one on screen, now beside the list.
      tester.view.physicalSize = desktop;
      await tester.pumpAndSettle();

      expect(find.text('chat:b'), findsOneWidget);
      expect(find.byType(ChatsListScreen), findsOneWidget);
    });

    testWidgets('one pane stacks the chat over the list', (tester) async {
      final router = await pumpShell(
        tester,
        size: phone,
        chats: [chat('a', unread: 0)],
      );

      router.go(const ChatDetailRoute('a').location);
      await tester.pumpAndSettle();

      expect(find.text('chat:a'), findsOneWidget);
      expect(find.byType(ChatsListScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(ChatsListScreen), findsNothing);
    });
  });

  group('scroll position', () {
    Finder listOf() => find.descendant(
      of: find.byType(ChatsListScreen),
      matching: find.byType(CustomScrollView),
    );

    double offsetOf(WidgetTester tester) =>
        tester.widget<CustomScrollView>(listOf()).controller!.offset;

    testWidgets('survives the rotation that moves the list between panes', (
      tester,
    ) async {
      await pumpShell(
        tester,
        size: phone,
        chats: [for (var i = 0; i < 40; i++) chat('c$i', unread: 0)],
      );

      await tester.drag(listOf(), const Offset(0, -300));
      await tester.pumpAndSettle();

      final before = offsetOf(tester);
      expect(before, greaterThan(0));

      // Crossing the breakpoint destroys one list and builds another, in a
      // different route with a different PageStorage bucket.
      tester.view.physicalSize = desktop;
      await tester.pumpAndSettle();

      expect(offsetOf(tester), closeTo(before, 1));
    });

    testWidgets('survives a trip through another tab', (tester) async {
      await pumpShell(
        tester,
        size: phone,
        chats: [for (var i = 0; i < 40; i++) chat('c$i', unread: 0)],
      );

      await tester.drag(listOf(), const Offset(0, -300));
      await tester.pumpAndSettle();
      final before = offsetOf(tester);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();

      expect(offsetOf(tester), closeTo(before, 1));
    });
  });

  group('leaving a full-screen form', () {
    testWidgets('the create form covers the shell', (tester) async {
      final router = await pumpShell(tester, size: desktop);

      router.push(CreateChatRoute.locationOf(CreateChatRoute.groupType));
      await tester.pumpAndSettle();

      expect(find.text('create:group'), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('replacing it with the new chat lands back in the shell', (
      tester,
    ) async {
      final router = await pumpShell(
        tester,
        size: desktop,
        chats: [chat('a', unread: 0), chat('b', unread: 0)],
      );

      router.push(CreateChatRoute.location);
      await tester.pumpAndSettle();

      // What the create screen does once the chat exists.
      router.pushReplacement(const ChatDetailRoute('b').location);
      await tester.pumpAndSettle();

      expect(find.text('create:any'), findsNothing);
      expect(find.text('chat:b'), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(ChatsListScreen), findsOneWidget);
    });
  });

  group('tabs', () {
    testWidgets('switching keeps every branch mounted', (tester) async {
      await pumpShell(tester, size: phone);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('settings-branch'), findsOneWidget);
      // The chats branch is still there, just not on top: its scroll position
      // and navigation stack come back untouched.
      expect(
        find.byType(ChatsListScreen, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('a tab returns to where it was left', (tester) async {
      final router = await pumpShell(
        tester,
        size: phone,
        chats: [chat('a', unread: 0)],
      );

      router.go(const ChatDetailRoute('a').location);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();
      expect(find.text('contacts-branch'), findsOneWidget);

      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();
      expect(find.text('chat:a'), findsOneWidget);
    });
  });

  group('the chats tab quick menu', () {
    testWidgets('opens on a long press', (tester) async {
      await pumpShell(tester, size: phone);

      await tester.longPress(find.byIcon(Icons.chat_bubble));
      await tester.pumpAndSettle();

      expect(find.text('New direct chat'), findsOneWidget);
      expect(find.text('New group'), findsOneWidget);
      expect(find.text('New channel'), findsOneWidget);
    });

    testWidgets('a plain tap still just switches tab', (tester) async {
      await pumpShell(tester, size: phone);

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();

      expect(find.text('New group'), findsNothing);
      expect(find.byType(ChatsListScreen), findsOneWidget);
    });

    testWidgets('picking "new group" opens the form on that type', (
      tester,
    ) async {
      await pumpShell(tester, size: phone);

      await tester.longPress(find.byIcon(Icons.chat_bubble));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New group'));
      await tester.pumpAndSettle();

      expect(find.text('create:group'), findsOneWidget);
    });

    testWidgets('reaches the chats tab from another tab', (tester) async {
      await pumpShell(tester, size: phone);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.longPress(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New channel'));
      await tester.pumpAndSettle();

      expect(find.text('create:channel'), findsOneWidget);
    });

    testWidgets('dismissing it leaves the current tab alone', (tester) async {
      await pumpShell(tester, size: phone);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.longPress(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      expect(find.text('settings-branch'), findsOneWidget);
    });

    testWidgets('the rail carries the same shortcut', (tester) async {
      await pumpShell(tester, size: tabletPortrait);

      await tester.longPress(find.byIcon(Icons.chat_bubble));
      await tester.pumpAndSettle();

      expect(find.text('New group'), findsOneWidget);
    });
  });
}
