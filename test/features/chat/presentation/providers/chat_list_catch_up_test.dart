import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_store.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/usecases/get_chats_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

class _MockGetChatsUseCase extends Mock implements GetChatsUseCase {}

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@example.com');
}

/// A socket whose status and events are driven by hand.
class _FakeSocket implements ChatSocketService {
  _FakeSocket(this._current);

  ChatSocketStatus _current;

  final StreamController<WSEvent> _events =
      StreamController<WSEvent>.broadcast();
  final StreamController<ChatSocketStatus> _statuses =
      StreamController<ChatSocketStatus>.broadcast();

  @override
  Stream<WSEvent> get events => _events.stream;

  @override
  Stream<ChatSocketStatus> get statusStream => _statuses.stream;

  @override
  ChatSocketStatus get status => _current;

  @override
  List<String> get subscribedChatIds => const [];

  void report(ChatSocketStatus next) {
    _current = next;
    _statuses.add(next);
  }

  Future<void> close() async {
    await _events.close();
    await _statuses.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// "Updating…" in the list's title: the list knows when it is fetching what
/// it missed — opened from the device's copy, or back from a dropped
/// connection, whose missed events are gone for good (api-docs §6.3).
void main() {
  ChatEntity chat(String id, {int unread = 0}) => ChatEntity(
    id: id,
    seqCounter: 10,
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
    unreadCount: unread,
  );

  Map<String, dynamic> row(String id) => {
    'id': id,
    'seq_counter': 10,
    'last_activity_at': '2026-01-01T00:00:00Z',
    'type': 'group',
    'name': 'Cached $id',
    'description': null,
    'avatar_s3_key': null,
    'is_public': false,
    'admin_only': false,
    'slow_mode_seconds': 0,
    'permissions': <String, bool>{},
    'created_by': 1,
    'member_count': 3,
    'unread_count': 1,
  };

  ChatsPage page(List<ChatEntity> chats) =>
      ChatsPage(chats: chats, hasNext: false, nextDate: null, nextChatId: null);

  late ChatLocalStore store;
  late _MockGetChatsUseCase getChats;
  late List<Completer<Either<Failure, ChatsPage>>> fetches;

  setUp(() {
    store = inMemoryChatLocalStore();
    getChats = _MockGetChatsUseCase();
    fetches = [];

    // Every fetch waits until the test answers it.
    when(
      () => getChats.execute(
        limit: any(named: 'limit'),
        archived: any(named: 'archived'),
      ),
    ).thenAnswer((_) {
      final fetch = Completer<Either<Failure, ChatsPage>>();
      fetches.add(fetch);
      return fetch.future;
    });
  });

  Future<void> fillCache() => store.writeChatList(
    CachedChatList(
      chats: [row('c1')],
      hasNext: false,
      nextDate: null,
      nextChatId: null,
      savedAt: DateTime.utc(2026),
    ),
  );

  ProviderContainer boot(_FakeSocket socket) {
    final container = ProviderContainer(
      overrides: [
        chatLocalDataSourceProvider.overrideWithValue(store),
        getChatsUseCaseProvider.overrideWithValue(getChats),
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(_FakeAuthController.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(socket.close);
    container.listen(chatListProvider, (_, _) {});
    return container;
  }

  ChatListState stateOf(ProviderContainer container) =>
      container.read(chatListProvider).value!;

  group('opened from the device copy', () {
    test('it is catching up until the fetch lands', () async {
      await fillCache();
      final container = boot(_FakeSocket(ChatSocketStatus.ready));

      final opened = await container.read(chatListProvider.future);
      expect(opened.items.single.name, 'Cached c1');
      expect(opened.isCatchingUp, isTrue);

      await pumpEventQueue();
      expect(fetches, hasLength(1));
      fetches.single.complete(Right(page([chat('c2')])));
      await pumpEventQueue();

      expect(stateOf(container).items.single.id, 'c2');
      expect(stateOf(container).isCatchingUp, isFalse);
    });

    test('a failed fetch stops saying so and keeps the rows', () async {
      await fillCache();
      final container = boot(_FakeSocket(ChatSocketStatus.ready));

      await container.read(chatListProvider.future);
      await pumpEventQueue();
      fetches.single.complete(const Left(NetworkFailure()));
      await pumpEventQueue();

      expect(stateOf(container).items.single.name, 'Cached c1');
      expect(stateOf(container).isCatchingUp, isFalse);
    });
  });

  group('the socket coming back', () {
    Future<ProviderContainer> loaded(_FakeSocket socket) async {
      final container = boot(socket);
      final loading = container.read(chatListProvider.future);
      await pumpEventQueue();
      fetches.single.complete(Right(page([chat('a')])));
      await loading;
      return container;
    }

    test('the first connection is left alone', () async {
      // The list is being fetched for it anyway.
      final socket = _FakeSocket(ChatSocketStatus.connecting);
      final container = await loaded(socket);

      socket.report(ChatSocketStatus.ready);
      await pumpEventQueue();

      expect(fetches, hasLength(1));
      expect(stateOf(container).isCatchingUp, isFalse);
    });

    test('after a drop it refetches, and says so meanwhile', () async {
      final socket = _FakeSocket(ChatSocketStatus.ready);
      final container = await loaded(socket);

      socket.report(ChatSocketStatus.reconnecting);
      await pumpEventQueue();
      expect(fetches, hasLength(1), reason: 'nothing to fetch with yet');

      socket.report(ChatSocketStatus.ready);
      await pumpEventQueue();
      expect(fetches, hasLength(2));
      expect(stateOf(container).isCatchingUp, isTrue);
      expect(stateOf(container).items.single.id, 'a');

      // What arrived while the socket was away is in the fresh page.
      fetches.last.complete(Right(page([chat('b', unread: 4), chat('a')])));
      await pumpEventQueue();

      expect(stateOf(container).items.map((c) => c.id), ['b', 'a']);
      expect(stateOf(container).isCatchingUp, isFalse);
    });

    test('a second drop mid-fetch does not start another', () async {
      final socket = _FakeSocket(ChatSocketStatus.ready);
      await loaded(socket);

      socket
        ..report(ChatSocketStatus.reconnecting)
        ..report(ChatSocketStatus.ready);
      await pumpEventQueue();
      socket
        ..report(ChatSocketStatus.reconnecting)
        ..report(ChatSocketStatus.ready);
      await pumpEventQueue();

      expect(fetches, hasLength(2));
      fetches.last.complete(Right(page([chat('a')])));
      await pumpEventQueue();
    });
  });
}
