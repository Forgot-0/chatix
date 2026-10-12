import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/router/app_shell.dart';
import 'package:chatix/core/router/chats_pane_shell.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/ui/desktop/desktop_scrolling.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_profile_provider.dart';
import 'package:chatix/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_jump_palette.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@example.com');
}

class _FakeChatListController extends ChatListController {
  _FakeChatListController(this._chats);

  final List<ChatEntity> _chats;

  @override
  Future<ChatListState> build() async => ChatListState(items: _chats);
}

class _FakeNotificationBadge extends NotificationBadgeController {
  @override
  int build() => 0;
}

/// Stands in for the screens the shortcuts take the reader to.
class _Probe extends StatelessWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

void main() {
  final l10n = AppLocalizationsEn();
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  ChatEntity chat(String id, String name, {int unread = 0}) => ChatEntity(
    id: id,
    seqCounter: 10,
    lastActivityAt: DateTime.utc(2026, 1, 1),
    type: ChatType.group,
    name: name,
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

  final chats = [
    chat('a', 'Alpha'),
    chat('b', 'Beta team', unread: 3),
    chat('c', 'Gamma'),
    chat('d', 'Design review'),
  ];

  GoRouter buildRouter() {
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
                      name: RouteNames.chats,
                      builder: (_, _) => const ChatsListPane(),
                      routes: [
                        GoRoute(
                          path: ChatSearchRoute.path,
                          parentNavigatorKey: rootNavigatorKey,
                          builder: (_, _) => const _Probe('search'),
                        ),
                        GoRoute(
                          path: ChatDetailRoute.path,
                          name: RouteNames.chatDetail,
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
                  routes: [
                    GoRoute(
                      path: AppearanceSettingsRoute.path,
                      builder: (_, _) => const _Probe('appearance'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  late ProviderContainer container;

  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = buildRouter();
    addTearDown(router.dispose);

    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_FakeAuthController.new),
        chatListProvider.overrideWith(() => _FakeChatListController(chats)),
        notificationBadgeProvider.overrideWith(_FakeNotificationBadge.new),
        chatOrganizerDataSourceProvider.overrideWithValue(
          InMemoryChatOrganizerDataSource(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          scrollBehavior: const AppScrollBehavior(),
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

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    List<LogicalKeyboardKey> holding = const [],
  }) async {
    for (final modifier in holding) {
      await tester.sendKeyDownEvent(modifier);
    }
    await tester.sendKeyEvent(key);
    for (final modifier in holding.reversed) {
      await tester.sendKeyUpEvent(modifier);
    }
    await tester.pumpAndSettle();
  }

  const alt = [LogicalKeyboardKey.altLeft];
  const ctrl = [LogicalKeyboardKey.controlLeft];
  const ctrlShift = [
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.shiftLeft,
  ];

  group('switching chats', () {
    testWidgets('Alt+↓ and Alt+↑ walk the list', (tester) async {
      await pumpShell(tester);

      await press(tester, LogicalKeyboardKey.arrowDown, holding: alt);
      expect(find.text('chat:a'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.arrowDown, holding: alt);
      expect(find.text('chat:b'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.arrowUp, holding: alt);
      expect(find.text('chat:a'), findsOneWidget);

      // The top of the list is where it stops.
      await press(tester, LogicalKeyboardKey.arrowUp, holding: alt);
      expect(find.text('chat:a'), findsOneWidget);
    }, variant: windows);

    testWidgets('Ctrl+Tab and Ctrl+Shift+Tab do the same', (tester) async {
      await pumpShell(tester);

      await press(tester, LogicalKeyboardKey.tab, holding: ctrl);
      await press(tester, LogicalKeyboardKey.tab, holding: ctrl);
      expect(find.text('chat:b'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.tab, holding: ctrlShift);
      expect(find.text('chat:a'), findsOneWidget);
    }, variant: windows);

    testWidgets('on one pane each step replaces the chat, not stacks it', (
      tester,
    ) async {
      final router = await pumpShell(tester, size: const Size(500, 900));

      await press(tester, LogicalKeyboardKey.arrowDown, holding: alt);
      await press(tester, LogicalKeyboardKey.arrowDown, holding: alt);
      expect(find.text('chat:b'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ChatsListScreen), findsOneWidget);
      expect(find.text('chat:a'), findsNothing);
    }, variant: windows);
  });

  group('Ctrl+F', () {
    testWidgets('with a chat open asks that chat for its search', (
      tester,
    ) async {
      final router = await pumpShell(tester);
      router.go(const ChatDetailRoute('b').location);
      await tester.pumpAndSettle();

      await press(tester, LogicalKeyboardKey.keyF, holding: ctrl);

      expect(container.read(chatSearchRequestProvider), 'b');
      expect(find.text('search'), findsNothing);
    }, variant: windows);

    testWidgets('with no chat open searches everything', (tester) async {
      await pumpShell(tester);

      await press(tester, LogicalKeyboardKey.keyF, holding: ctrl);

      expect(find.text('search'), findsOneWidget);
      expect(container.read(chatSearchRequestProvider), isNull);
    }, variant: windows);
  });

  testWidgets('Ctrl+, opens the settings page itself', (tester) async {
    final router = await pumpShell(tester);
    router.go(AppearanceSettingsRoute.location);
    await tester.pumpAndSettle();
    router.go(ChatsRoute.location);
    await tester.pumpAndSettle();

    await press(tester, LogicalKeyboardKey.comma, holding: ctrl);

    expect(find.text('settings-branch'), findsOneWidget);
    expect(find.text('appearance'), findsNothing);
  }, variant: windows);

  testWidgets(
    'a Mac uses Cmd, not Ctrl',
    (tester) async {
      await pumpShell(tester);

      await press(tester, LogicalKeyboardKey.comma, holding: ctrl);
      expect(find.text('settings-branch'), findsNothing);

      await press(
        tester,
        LogicalKeyboardKey.comma,
        holding: const [LogicalKeyboardKey.metaLeft],
      );
      expect(find.text('settings-branch'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'a phone has none of them',
    (tester) async {
      await pumpShell(tester, size: const Size(400, 800));

      await press(tester, LogicalKeyboardKey.arrowDown, holding: alt);
      await press(tester, LogicalKeyboardKey.keyK, holding: ctrl);

      expect(find.text('chat:a'), findsNothing);
      expect(find.byType(ChatJumpPalette), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  group('the Ctrl+K palette', () {
    testWidgets('lists the chats in the list\'s order', (tester) async {
      await pumpShell(tester);

      await press(tester, LogicalKeyboardKey.keyK, holding: ctrl);

      expect(find.byType(ChatJumpPalette), findsOneWidget);
      final titles = find.descendant(
        of: find.byType(ChatJumpPalette),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text && chats.any((chat) => chat.name == widget.data),
        ),
      );
      expect(tester.widgetList<Text>(titles).map((text) => text.data), [
        'Alpha',
        'Beta team',
        'Gamma',
        'Design review',
      ]);
    }, variant: windows);

    testWidgets('narrows as the name is typed, and Enter opens it', (
      tester,
    ) async {
      await pumpShell(tester);
      await press(tester, LogicalKeyboardKey.keyK, holding: ctrl);

      await tester.enterText(find.byType(TextField), 'gam');
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(ChatJumpPalette),
          matching: find.text('Alpha'),
        ),
        findsNothing,
      );

      await press(tester, LogicalKeyboardKey.enter);

      expect(find.byType(ChatJumpPalette), findsNothing);
      expect(find.text('chat:c'), findsOneWidget);
    }, variant: windows);

    testWidgets('the arrows choose; Esc closes without going anywhere', (
      tester,
    ) async {
      await pumpShell(tester);
      await press(tester, LogicalKeyboardKey.keyK, holding: ctrl);

      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.text('chat:b'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.keyK, holding: ctrl);
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ChatJumpPalette), findsNothing);
      expect(find.text('chat:b'), findsOneWidget);
    }, variant: windows);

    testWidgets('while it is open the shell keys stand down', (tester) async {
      await pumpShell(tester);
      await press(tester, LogicalKeyboardKey.keyK, holding: ctrl);

      await press(tester, LogicalKeyboardKey.arrowDown, holding: alt);
      await press(tester, LogicalKeyboardKey.keyK, holding: ctrl);

      expect(find.byType(ChatJumpPalette), findsOneWidget);
      expect(find.text('chat:a'), findsNothing);

      // …and come back once it is gone.
      await press(tester, LogicalKeyboardKey.escape);
      await press(tester, LogicalKeyboardKey.arrowDown, holding: alt);
      expect(find.text('chat:a'), findsOneWidget);
    }, variant: windows);

    testWidgets('says so when nothing matches', (tester) async {
      await pumpShell(tester);
      await press(tester, LogicalKeyboardKey.keyK, holding: ctrl);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();

      expect(find.text(l10n.chatJumpNothingFound), findsOneWidget);
    }, variant: windows);

    group('goldens', () {
      for (final MapEntry(key: name, value: size) in {
        'phone': const Size(390, 844),
        'desktop': const Size(1440, 900),
      }.entries) {
        for (final MapEntry(key: theme, value: dark) in {
          'light': false,
          'dark': true,
        }.entries) {
          testGoldens('$name, $theme', (tester) async {
            debugDefaultTargetPlatformOverride = TargetPlatform.windows;
            EditableText.debugDeterministicCursor = true;
            try {
              await pumpShell(tester, size: size, dark: dark);
              await press(tester, LogicalKeyboardKey.keyK, holding: ctrl);
              await tester.enterText(find.byType(TextField), 'a');
              await press(tester, LogicalKeyboardKey.arrowDown);

              await screenMatchesGolden(tester, 'chat_jump_${name}_$theme');
            } finally {
              debugDefaultTargetPlatformOverride = null;
              EditableText.debugDeterministicCursor = false;
            }
          });
        }
      }
    });
  });

  group('ChatJumpPalette.rank', () {
    String titleOf(ChatEntity chat) => chat.name!;

    test('puts names that start with the query first, then words in them', () {
      final ranked = ChatJumpPalette.rank(
        [
          chat('1', 'Release crew'),
          chat('2', 'Team retro'),
          chat('3', 'Retro board'),
          chat('4', 'Unrelated'),
        ],
        're',
        titleOf,
      );

      expect(ranked.map(titleOf), [
        'Release crew',
        'Retro board',
        'Team retro',
        'Unrelated',
      ]);
    });

    test('ignores case and the spaces around the query', () {
      final ranked = ChatJumpPalette.rank(
        [chat('1', 'Gamma')],
        '  GAM ',
        titleOf,
      );
      expect(ranked, hasLength(1));
    });

    test('an empty query keeps every chat in order', () {
      expect(ChatJumpPalette.rank(chats, '', titleOf), chats);
    });
  });
}
