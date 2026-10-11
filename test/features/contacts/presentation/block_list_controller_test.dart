import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chats_badge_provider.dart';
import 'package:chatix/features/contacts/data/datasources/block_list_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/blocked_users_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/features/contacts/presentation/providers/blocked_users_providers.dart';
import 'package:chatix/features/notification/data/datasources/blocked_senders_store.dart';
import 'package:chatix/features/notification/domain/entities/blocked_senders.dart';

import '../../../helpers/blocked_users_fixtures.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;

  void signOut() => state = const AsyncValue.data(null);
}

class _FakeChatList extends ChatListController {
  _FakeChatList(this._state);

  final ChatListState _state;

  @override
  Future<ChatListState> build() async => _state;
}

const _me = UserEntity(id: 7, username: 'me', email: 'me@x.io');

ChatEntity _chat(String id, {int? peer, int unread = 0}) => ChatEntity(
  id: id,
  seqCounter: 10,
  lastActivityAt: DateTime.utc(2026, 10, 1),
  type: peer == null ? ChatType.group : ChatType.direct,
  name: peer == null ? 'Group $id' : null,
  description: null,
  avatarS3Key: null,
  isPublic: false,
  adminOnly: false,
  slowModeSeconds: 0,
  permissions: const {},
  createdBy: 7,
  memberCount: peer == null ? 5 : 2,
  unreadCount: unread,
  peer: peer == null
      ? null
      : ChatProfileEntity(
          userId: peer,
          username: 'user$peer',
          displayName: null,
          avatarUrl: null,
          avatarS3Key: null,
        ),
);

/// What the app does with a block before the server does anything with it
/// ("этап 2", api-docs §4.13): the composer, the badge, the notifications.
void main() {
  late FakeBlockedUsersRemote remote;
  late MemoryBlockListLocalStore store;
  late MemoryBlockedSendersStore senders;
  late _FakeAuth auth;

  setUp(() {
    remote = FakeBlockedUsersRemote();
    store = MemoryBlockListLocalStore();
    senders = MemoryBlockedSendersStore();
  });

  Future<ProviderContainer> container({
    List<ChatEntity> chats = const [],
  }) async {
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => auth = _FakeAuth(_me)),
        blockListLocalStoreProvider.overrideWithValue(store),
        blockedSendersStoreProvider.overrideWithValue(senders),
        blockedUsersRepositoryProvider.overrideWith(
          (ref) => BlockedUsersRepositoryImpl(remote: remote, local: store),
        ),
        chatListProvider.overrideWith(
          () => _FakeChatList(ChatListState(items: chats)),
        ),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    return c;
  }

  group('the block list', () {
    test('opens on the stored copy, without a request', () async {
      await store.save(const BlockList(ownerId: 7, userIds: {42}));
      final c = await container();

      expect(c.read(isUserBlockedProvider(42)), isTrue);
      expect(c.read(isUserBlockedProvider(43)), isFalse);
      expect(c.read(blockedCountProvider), 1);
      expect(remote.pages, isEmpty);
    });

    test('nothing stored is "not known yet", not "nobody"', () async {
      final c = await container();

      expect(c.read(blockedCountProvider), isNull);
    });

    test('a block shows before the server has answered', () async {
      final answer = Completer<Either<Failure, void>>();
      remote.onBlock = (_) => answer.future;
      final c = await container();

      final blocking = c.read(blockListProvider.notifier).block(42);

      expect(c.read(isUserBlockedProvider(42)), isTrue);
      expect(c.read(isBlockBusyProvider(42)), isTrue);

      answer.complete(const Right(null));
      await blocking;

      expect(c.read(isUserBlockedProvider(42)), isTrue);
      expect(c.read(isBlockBusyProvider(42)), isFalse);
      expect(store.read()?.userIds, {42});
    });

    test('a refused block is taken back', () async {
      remote.onBlock = (_) async => const Left(NetworkFailure());
      final c = await container();

      final result = await c.read(blockListProvider.notifier).block(42);

      expect(result, const Left(NetworkFailure()));
      expect(c.read(isUserBlockedProvider(42)), isFalse);
    });

    test('a refused unblock puts the block back', () async {
      await store.save(const BlockList(ownerId: 7, userIds: {42}));
      remote.onUnblock = (_) async => const Left(NetworkFailure());
      final c = await container();

      await c.read(blockListProvider.notifier).unblock(42);

      expect(c.read(isUserBlockedProvider(42)), isTrue);
    });

    test('a second tap while the first is on the wire sends nothing', () async {
      final answer = Completer<Either<Failure, void>>();
      remote.onBlock = (_) => answer.future;
      final c = await container();
      final notifier = c.read(blockListProvider.notifier);

      final first = notifier.block(42);
      await notifier.block(42);
      answer.complete(const Right(null));
      await first;

      expect(remote.blocks, [42]);
    });

    test('sync makes the state what the server says', () async {
      await store.save(const BlockList(ownerId: 7, userIds: {99}));
      remote.onPage = blockedPagesOf([blockedUser(42), blockedUser(43)]);
      final c = await container();

      await c.read(blockListProvider.notifier).sync();

      expect(c.read(blockedUserIdsProvider), {42, 43});
    });
  });

  group('the lifecycle', () {
    test('signing out forgets the list and the notification copy', () async {
      await store.save(const BlockList(ownerId: 7, userIds: {42}));
      await senders.save(const BlockedSenders(userIds: {42}));
      final c = await container();
      c.listen(blockListLifecycleProvider, (_, _) {});
      await pumpEventQueue();

      auth.signOut();
      await pumpEventQueue();

      expect(store.read(), isNull);
      expect(senders.load(), BlockedSenders.none);
      expect(c.read(blockedUserIdsProvider), isEmpty);
    });

    test('signed in at launch, it syncs', () async {
      remote.onPage = blockedPagesOf([blockedUser(42)]);
      final c = await container();

      c.listen(blockListLifecycleProvider, (_, _) {});
      await pumpEventQueue();

      expect(remote.pages, isNotEmpty);
      expect(c.read(blockedUserIdsProvider), {42});
    });
  });

  group('what a block quiets', () {
    final chats = [
      _chat('direct-42', peer: 42, unread: 3),
      _chat('direct-43', peer: 43, unread: 2),
      _chat('group', unread: 5),
    ];

    test('nobody blocked: the chat list is not even looked at', () async {
      final c = await container(chats: chats);

      expect(c.read(blockedDirectChatIdsProvider), isEmpty);
      expect(c.read(blockedSendersProvider), BlockedSenders.none);
      expect(c.exists(chatListProvider), isFalse);
    });

    test(
      'the direct chat with a blocked person is found by its peer',
      () async {
        await store.save(const BlockList(ownerId: 7, userIds: {42}));
        final c = await container(chats: chats);
        await c.read(chatListProvider.future);

        expect(c.read(blockedDirectChatIdsProvider), {'direct-42'});
        expect(
          c.read(blockedSendersProvider),
          const BlockedSenders(userIds: {42}, directChatIds: {'direct-42'}),
        );
      },
    );

    test('the badge leaves that chat out, and only that chat', () async {
      await store.save(const BlockList(ownerId: 7, userIds: {42}));
      final c = await container(chats: chats);
      await c.read(chatListProvider.future);

      expect(c.read(chatsUnreadBadgeProvider), 2 + 5);

      await c.read(blockListProvider.notifier).unblock(42);
      await pumpEventQueue();

      expect(c.read(chatsUnreadBadgeProvider), 3 + 2 + 5);
    });

    test('the copy for the background isolate follows along', () async {
      await store.save(const BlockList(ownerId: 7, userIds: {42}));
      final c = await container(chats: chats);
      await c.read(chatListProvider.future);
      c.listen(blockedSendersSnapshotProvider, (_, _) {});
      await pumpEventQueue();

      expect(
        senders.load(),
        const BlockedSenders(userIds: {42}, directChatIds: {'direct-42'}),
      );

      await c.read(blockListProvider.notifier).block(43);
      await pumpEventQueue();

      expect(
        senders.load(),
        const BlockedSenders(
          userIds: {42, 43},
          directChatIds: {'direct-42', 'direct-43'},
        ),
      );
    });
  });

  group('the screen\'s list', () {
    test('reads the first page and tells the app who is on it', () async {
      remote.onPage = blockedPagesOf([blockedUser(42), blockedUser(43)]);
      final c = await container();

      final state = await c.read(blockedUsersListProvider.future);

      expect(state.users.map((user) => user.userId), [42, 43]);
      expect(state.hasNext, isFalse);
      expect(c.read(blockedUserIdsProvider), {42, 43});
    });

    test('pages on by the cursor, without repeating a row', () async {
      final users = [for (var id = 1; id <= 60; id++) blockedUser(id)];
      remote.onPage = blockedPagesOf(users);
      final c = await container();
      final sub = c.listen(blockedUsersListProvider, (_, _) {});
      addTearDown(sub.close);

      final first = await c.read(blockedUsersListProvider.future);
      expect(first.users, hasLength(50));
      expect(first.canLoadMore, isTrue);

      await c.read(blockedUsersListProvider.notifier).loadMore();

      final state = c.read(blockedUsersListProvider).value!;
      expect(state.users, hasLength(60));
      expect(state.users.map((user) => user.userId).toSet(), hasLength(60));
      expect(state.hasNext, isFalse);
      expect(remote.pages.last.afterTargetId, 50);
    });

    test('a failed "more" keeps the rows and says why', () async {
      final users = [for (var id = 1; id <= 60; id++) blockedUser(id)];
      final pages = blockedPagesOf(users);
      remote.onPage = (request) => request.afterTargetId == null
          ? pages(request)
          : Future.value(const Left(NetworkFailure()));
      final c = await container();
      final sub = c.listen(blockedUsersListProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(blockedUsersListProvider.future);

      await c.read(blockedUsersListProvider.notifier).loadMore();

      final state = c.read(blockedUsersListProvider).value!;
      expect(state.users, hasLength(50));
      expect(state.loadMoreFailure, const NetworkFailure());
      expect(state.isLoadingMore, isFalse);
    });
  });
}
