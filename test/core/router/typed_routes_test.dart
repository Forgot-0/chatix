import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';

void main() {
  ({GoRouter router, List<Object?> parsed}) buildRouter() {
    final parsed = <Object?>[];

    final router = GoRouter(
      initialLocation: ChatsRoute.path,
      routes: [
        GoRoute(
          path: ChatsRoute.path,
          builder: (_, _) => const Placeholder(),
          routes: [
            GoRoute(
              path: CreateChatRoute.path,
              builder: (_, _) {
                parsed.add('create-chat');
                return const Placeholder();
              },
            ),
            GoRoute(
              path: ChatSearchRoute.path,
              builder: (_, _) {
                parsed.add('chat-search');
                return const Placeholder();
              },
            ),
            GoRoute(
              path: ChatDetailRoute.path,
              builder: (_, state) {
                parsed.add(ChatDetailRoute.idFrom(state));
                return const Placeholder();
              },
            ),
          ],
        ),
        GoRoute(
          path: ProfilesRoute.path,
          builder: (_, _) => const Placeholder(),
          routes: [
            GoRoute(
              path: ProfileDetailRoute.path,
              builder: (_, state) {
                parsed.add(ProfileDetailRoute.idFrom(state));
                return const Placeholder();
              },
            ),
          ],
        ),
        GoRoute(
          path: NotificationsRoute.path,
          builder: (_, _) {
            parsed.add('notifications');
            return const Placeholder();
          },
        ),
      ],
    );

    return (router: router, parsed: parsed);
  }

  Future<List<Object?>> go(WidgetTester tester, String location) async {
    final harness = buildRouter();
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: harness.router));
    harness.router.go(location);
    await tester.pumpAndSettle();
    return harness.parsed;
  }

  group('locations are built from the typed constructors', () {
    test('chat ids stay strings, profile ids stay ints', () {
      expect(const ChatDetailRoute('9f8e-uuid').location, '/chats/9f8e-uuid');
      expect(const ProfileDetailRoute(17).location, '/profiles/17');
      expect(ChatMembersRoute.locationOf('9f8e'), '/chats/9f8e/members');
      expect(ChatCallRoute.locationOf('9f8e'), '/chats/9f8e/call');
    });
  });

  group('/chats/:chatId', () {
    testWidgets('hands the screen the UUID string, unparsed', (tester) async {
      final parsed = await go(
        tester,
        const ChatDetailRoute('7c0b1f2e-uuid').location,
      );
      expect(parsed, ['7c0b1f2e-uuid']);
    });

    testWidgets('the static "create" child wins over :chatId', (tester) async {
      final parsed = await go(tester, CreateChatRoute.location);
      expect(parsed, ['create-chat']);
    });

    testWidgets('the static "search" child wins over :chatId', (tester) async {
      final parsed = await go(tester, ChatSearchRoute.location);
      expect(parsed, ['chat-search']);
    });
  });

  group('/profiles/:profileId', () {
    testWidgets('parses the int id', (tester) async {
      final parsed = await go(tester, const ProfileDetailRoute(17).location);
      expect(parsed, [17]);
    });
  });

  group('/notifications', () {
    testWidgets('takes no parameters', (tester) async {
      final parsed = await go(tester, NotificationsRoute.location);
      expect(parsed, ['notifications']);
    });
  });
}