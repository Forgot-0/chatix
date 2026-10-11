import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/contacts/data/datasources/block_list_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/blocked_users_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';
import 'package:chatix/features/contacts/domain/usecases/block_use_cases.dart';

import '../../../helpers/blocked_users_fixtures.dart';

const int _owner = 7;

/// The block list repository: the server's list, and the copy of it on this
/// device that every client-side effect of a block reads.
void main() {
  late FakeBlockedUsersRemote remote;
  late MemoryBlockListLocalStore store;
  late BlockedUsersRepositoryImpl repository;

  setUp(() {
    remote = FakeBlockedUsersRemote(
      users: [blockedUser(42), blockedUser(43), blockedUser(44)],
    );
    store = MemoryBlockListLocalStore();
    repository = BlockedUsersRepositoryImpl(
      remote: remote,
      local: store,
      syncPageSize: 2,
    );
  });

  group('a page for the screen', () {
    test('a first page that is also the last becomes the whole copy', () async {
      // Somebody unblocked on another device is still in the old copy.
      await store.save(const BlockList(ownerId: _owner, userIds: {42, 99}));
      remote.onPage = blockedPagesOf([blockedUser(42), blockedUser(43)]);

      final page = await repository.fetchPage(ownerId: _owner);

      expect(page.isRight(), isTrue);
      expect(store.read(), const BlockList(ownerId: _owner, userIds: {42, 43}));
    });

    test('a page of many adds whoever is on it, and keeps the rest', () async {
      await store.save(const BlockList(ownerId: _owner, userIds: {99}));
      remote.onPage = (request) async => Right(
        BlockedPage(users: [blockedUser(42)], hasNext: true, nextTargetId: 42),
      );

      await repository.fetchPage(ownerId: _owner);

      expect(store.read()?.userIds, {42, 99});
    });

    test('the cursor goes out as after_target_id', () async {
      await repository.fetchPage(ownerId: _owner, afterTargetId: 42);

      expect(remote.pages.single.afterTargetId, 42);
    });

    test('a failure leaves the copy alone', () async {
      await store.save(const BlockList(ownerId: _owner, userIds: {99}));
      remote.onPage = (_) async => const Left(NetworkFailure());

      expect(
        await repository.fetchPage(ownerId: _owner),
        const Left(NetworkFailure()),
      );
      expect(store.read()?.userIds, {99});
    });
  });

  group('sync', () {
    test('reads every page by the cursor and replaces the copy', () async {
      await store.save(const BlockList(ownerId: _owner, userIds: {99}));

      final result = await repository.sync(ownerId: _owner);

      expect(
        result,
        const Right(BlockList(ownerId: _owner, userIds: {42, 43, 44})),
      );
      expect(remote.pages.map((page) => page.afterTargetId), [null, 43]);
      expect(remote.pages.every((page) => page.limit == 2), isTrue);
      expect(store.read()?.userIds, {42, 43, 44});
    });

    test('a copy left by another account is replaced, not merged', () async {
      await store.save(const BlockList(ownerId: 8, userIds: {99}));

      await repository.sync(ownerId: _owner);

      expect(
        store.read(),
        const BlockList(ownerId: _owner, userIds: {42, 43, 44}),
      );
    });

    test('a cursor that does not move gives up instead of looping', () async {
      remote.onPage = (_) async => Right(
        BlockedPage(users: [blockedUser(42)], hasNext: true, nextTargetId: 42),
      );

      final result = await repository.sync(ownerId: _owner);

      expect(result, const Left(BlockListCursorFailure()));
      expect(remote.pages, hasLength(2));
    });

    test('two at once share one read', () async {
      final first = repository.sync(ownerId: _owner);
      final second = repository.sync(ownerId: _owner);

      expect(await first, await second);
      expect(remote.pages, hasLength(2));
    });

    test('a block made while the pages are read is not lost', () async {
      final gate = Completer<void>();
      final pages = blockedPagesOf([blockedUser(42), blockedUser(43)]);
      remote.onPage = (request) async {
        await gate.future;
        return pages(request);
      };

      final syncing = repository.sync(ownerId: _owner);
      await repository.block(77, ownerId: _owner);
      await repository.unblock(42, ownerId: _owner);
      gate.complete();

      final result = await syncing;

      expect(result.getOrElse((_) => throw '').userIds, {43, 77});
      expect(store.read()?.userIds, {43, 77});
    });
  });

  group('block and unblock', () {
    test('a block goes to the server and then into the copy', () async {
      await store.save(const BlockList(ownerId: _owner, userIds: {42}));

      final result = await repository.block(43, ownerId: _owner);

      expect(result.isRight(), isTrue);
      expect(remote.blocks, [43]);
      expect(store.read()?.userIds, {42, 43});
    });

    test('blocking somebody twice is not an error', () async {
      await repository.block(43, ownerId: _owner);
      await repository.block(43, ownerId: _owner);

      expect(store.read()?.userIds, {43});
    });

    test('an unblock takes them out of the copy', () async {
      await store.save(const BlockList(ownerId: _owner, userIds: {42, 43}));

      await repository.unblock(42, ownerId: _owner);

      expect(remote.unblocks, [42]);
      expect(store.read()?.userIds, {43});
    });

    test('a refusal is read as the contacts failure it is', () async {
      remote.onBlock = (_) async => const Left(
        ApiFailure(
          code: 'SELF_CONTACT_NOT_ALLOWED',
          message: 'Self contact is not allowed',
          detail: {},
          status: 400,
        ),
      );

      final result = await repository.block(_owner, ownerId: _owner);

      expect(result, const Left(SelfContactFailure()));
      expect(store.read(), isNull);
    });

    test('a failed unblock leaves them blocked here', () async {
      await store.save(const BlockList(ownerId: _owner, userIds: {42}));
      remote.onUnblock = (_) async => const Left(NetworkFailure());

      await repository.unblock(42, ownerId: _owner);

      expect(store.read()?.userIds, {42});
    });
  });

  group('the use cases', () {
    test('blocking oneself is refused without asking the server', () async {
      final result = await BlockUserUseCase(
        repository,
      ).execute(_owner, ownerId: _owner);

      expect(result, const Left(SelfContactFailure()));
      expect(remote.blocks, isEmpty);
    });

    test('anybody else goes through', () async {
      await BlockUserUseCase(repository).execute(42, ownerId: _owner);
      await UnblockUserUseCase(repository).execute(42, ownerId: _owner);

      expect(remote.blocks, [42]);
      expect(remote.unblocks, [42]);
    });
  });

  group('the copy on disk', () {
    test('survives a restart, ids and owner', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await PrefsBlockListLocalStore(
        prefs,
      ).save(const BlockList(ownerId: _owner, userIds: {44, 42}));

      expect(
        PrefsBlockListLocalStore(prefs).read(),
        const BlockList(ownerId: _owner, userIds: {42, 44}),
      );
    });

    test('an unreadable entry is no copy, not a crash', () async {
      SharedPreferences.setMockInitialValues({
        PrefsBlockListLocalStore.storageKey: '{not json',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(PrefsBlockListLocalStore(prefs).read(), isNull);
    });

    test('clearing forgets it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final disk = PrefsBlockListLocalStore(prefs);
      await disk.save(const BlockList(ownerId: _owner, userIds: {42}));

      await disk.clear();

      expect(disk.read(), isNull);
      expect(prefs.getString(PrefsBlockListLocalStore.storageKey), isNull);
    });
  });
}
