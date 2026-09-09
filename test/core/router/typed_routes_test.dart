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
              builder: (_, state) {
                parsed.add(
                  'create-chat:${CreateChatRoute.typeFrom(state) ?? 'none'}',
                );
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
                parsed.add(ChatDetailRoute.messageSeqFrom(state));
                parsed.add(ChatDetailRoute.messageIdFrom(state));
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
      expect(parsed, ['7c0b1f2e-uuid', null, null]);
    });

    testWidgets('the static "create" child wins over :chatId', (tester) async {
      final parsed = await go(tester, CreateChatRoute.location);
      expect(parsed, ['create-chat:none']);
    });

    testWidgets('the static "search" child wins over :chatId', (tester) async {
      final parsed = await go(tester, ChatSearchRoute.location);
      expect(parsed, ['chat-search']);
    });
  });

  // `/chats/{id}?message={seq}` is the deep link into a single message: seq is
  // what `GET /chats/{id}/messages/context/?target_seq=` takes, so a link that
  // carries it needs no lookup before it can jump.
  group('/chats/:chatId?message=', () {
    test('a seq round-trips through the location', () {
      expect(
        const ChatDetailRoute('9f8e', messageSeq: 42).location,
        '/chats/9f8e?message=42',
      );
    });

    test('an id takes the other parameter, so the two never collide', () {
      expect(
        const ChatDetailRoute('9f8e', messageId: 'm-77').location,
        '/chats/9f8e?message_id=m-77',
      );
    });

    test('a seq wins when a caller supplies both', () {
      expect(
        const ChatDetailRoute('9f8e', messageSeq: 42, messageId: 'm-77')
            .location,
        '/chats/9f8e?message=42',
      );
    });

    testWidgets('parses ?message= as a seq', (tester) async {
      final parsed = await go(
        tester,
        const ChatDetailRoute('9f8e', messageSeq: 42).location,
      );
      expect(parsed, ['9f8e', 42, null]);
    });

    testWidgets('parses ?message_id= as an id', (tester) async {
      final parsed = await go(
        tester,
        const ChatDetailRoute('9f8e', messageId: 'm-77').location,
      );
      expect(parsed, ['9f8e', null, 'm-77']);
    });

    testWidgets('reads a non-numeric ?message= as an id', (tester) async {
      // Links minted before the seq form existed still land on the message.
      final parsed = await go(tester, '/chats/9f8e?message=7c0b-uuid');
      expect(parsed, ['9f8e', null, '7c0b-uuid']);
    });

    testWidgets('ignores a seq that cannot be one', (tester) async {
      final parsed = await go(tester, '/chats/9f8e?message=0');
      expect(parsed, ['9f8e', null, null]);
    });
  });

  group('/chats/create', () {
    test('carries the chat type as its wire value', () {
      expect(
        CreateChatRoute.locationOf(CreateChatRoute.groupType),
        '/chats/create?type=group',
      );
    });

    testWidgets('parses the type back out', (tester) async {
      final harness = buildRouter();
      addTearDown(harness.router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: harness.router));

      harness.router.go(
        CreateChatRoute.locationOf(CreateChatRoute.channelType),
      );
      await tester.pumpAndSettle();

      expect(harness.parsed, ['create-chat:channel']);
    });

    testWidgets('a plain /chats/create carries no type', (tester) async {
      final parsed = await go(tester, CreateChatRoute.location);
      expect(parsed, ['create-chat:none']);
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