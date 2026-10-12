import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_switch_provider.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';

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

void main() {
  group('ChatSwitching.neighbour', () {
    const order = ['a', 'b', 'c'];

    test('steps down and up the list', () {
      expect(ChatSwitching.neighbour(order, 'a', 1), 'b');
      expect(ChatSwitching.neighbour(order, 'c', -1), 'b');
    });

    test('stops at either end rather than wrapping round', () {
      expect(ChatSwitching.neighbour(order, 'c', 1), isNull);
      expect(ChatSwitching.neighbour(order, 'a', -1), isNull);
    });

    test('with nothing open, down starts at the top and up at the bottom', () {
      expect(ChatSwitching.neighbour(order, null, 1), 'a');
      expect(ChatSwitching.neighbour(order, null, -1), 'c');
    });

    test('a chat that is not in the list counts as nothing open', () {
      expect(ChatSwitching.neighbour(order, 'archived', 1), 'a');
    });

    test('an empty list has nowhere to go', () {
      expect(ChatSwitching.neighbour(const [], null, 1), isNull);
    });
  });

  group('visibleChatOrderProvider', () {
    ChatEntity chat(String id, {bool pinned = false, bool archived = false}) =>
        ChatEntity(
          id: id,
          seqCounter: 1,
          lastActivityAt: DateTime.utc(2026, 1, 1),
          type: ChatType.group,
          name: 'Chat $id',
          description: null,
          avatarS3Key: null,
          isPublic: false,
          adminOnly: false,
          slowModeSeconds: 0,
          permissions: const {},
          createdBy: 1,
          memberCount: 3,
          state: pinned || archived
              ? ChatStateEntity(isPinned: pinned, isArchived: archived)
              : null,
        );

    test('is the order the list draws: pinned first, archive left out', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_FakeAuthController.new),
          chatOrganizerDataSourceProvider.overrideWithValue(
            InMemoryChatOrganizerDataSource(),
          ),
          chatListProvider.overrideWith(
            () => _FakeChatListController([
              chat('a'),
              chat('b', pinned: true),
              chat('c', archived: true),
              chat('d'),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      await container.read(chatOrganizerProvider.future);
      await container.read(chatListProvider.future);

      expect(container.read(visibleChatOrderProvider), ['b', 'a', 'd']);
    });
  });

  group('which chat is open', () {
    Future<GoRouter> pumpRouter(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: ChatsRoute.location,
        routes: [
          GoRoute(
            path: ChatsRoute.path,
            name: RouteNames.chats,
            builder: (_, _) => const Text('list'),
            routes: [
              GoRoute(
                path: ChatDetailRoute.path,
                name: RouteNames.chatDetail,
                builder: (_, state) =>
                    Text('chat:${ChatDetailRoute.idFrom(state)}'),
                routes: [
                  GoRoute(
                    path: ChatInfoRoute.path,
                    name: RouteNames.chatInfo,
                    builder: (_, _) => const Text('info'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('none on the list itself', (tester) async {
      final router = await pumpRouter(tester);

      expect(ChatSwitching.currentChatId(router), isNull);
      expect(ChatSwitching.visibleChatId(router), isNull);
    });

    testWidgets('the one gone to', (tester) async {
      final router = await pumpRouter(tester);

      router.go(const ChatDetailRoute('a').location);
      await tester.pumpAndSettle();

      expect(ChatSwitching.currentChatId(router), 'a');
      expect(ChatSwitching.visibleChatId(router), 'a');
    });

    testWidgets('the one pushed, though the URI stays behind', (tester) async {
      final router = await pumpRouter(tester);

      router.push(const ChatDetailRoute('b').location);
      await tester.pumpAndSettle();

      expect(find.text('chat:b'), findsOneWidget);
      expect(ChatSwitching.currentChatId(router), 'b');
      expect(ChatSwitching.visibleChatId(router), 'b');
    });

    testWidgets('its info on top still belongs to it, but hides it', (
      tester,
    ) async {
      final router = await pumpRouter(tester);

      router.go(ChatInfoRoute.locationOf('a'));
      await tester.pumpAndSettle();

      expect(ChatSwitching.currentChatId(router), 'a');
      expect(ChatSwitching.visibleChatId(router), isNull);
    });
  });
}
