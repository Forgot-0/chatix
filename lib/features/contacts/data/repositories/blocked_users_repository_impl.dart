import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/contacts/data/datasources/block_list_local_store.dart';
import 'package:chatix/features/contacts/data/datasources/blocked_users_remote_data_source.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';
import 'package:chatix/features/contacts/domain/repositories/blocked_users_repository.dart';

/// The block list cursor stopped moving: the same page would be asked for
/// forever.
class BlockListCursorFailure extends Failure {
  const BlockListCursorFailure()
    : super(message: 'The block list cursor did not advance');
}

class BlockedUsersRepositoryImpl implements BlockedUsersRepository {
  BlockedUsersRepositoryImpl({
    required BlockedUsersRemoteDataSource remote,
    required BlockListLocalStore local,
    this.syncPageSize = BlockedUsersApi.maxPageSize,
  }) : _remote = remote,
       _local = local;

  final BlockedUsersRemoteDataSource _remote;
  final BlockListLocalStore _local;

  final int syncPageSize;

  /// Far past any list a person keeps; a server still saying `has_next`
  /// beyond it is not going to stop.
  static const int maxPages = 100;

  /// The sync in progress, shared by whoever asks for one meanwhile.
  Future<Either<Failure, BlockList>>? _syncing;
  int? _syncingOwner;

  /// Blocks and unblocks made while a sync was reading pages, and which way
  /// each went. The pages may predate them, so these win over the pages.
  final Map<int, bool> _changedDuringSync = <int, bool>{};

  @override
  BlockList? cached() => _local.read();

  @override
  Future<Either<Failure, BlockedPage>> fetchPage({
    required int ownerId,
    int? afterTargetId,
  }) async {
    final result = await _remote.fetchPage(afterTargetId: afterTargetId);

    switch (result) {
      case Left(value: final failure):
        return Left(contactFailureFrom(failure));
      case Right(value: final page):
        final seen = {for (final user in page.users) user.userId};
        // A first page that is also the last is the whole list: the copy
        // can become exactly it, unblocks from elsewhere included.
        if (afterTargetId == null && !page.hasNext) {
          await _save(BlockList(ownerId: ownerId, userIds: seen));
        } else if (seen.isNotEmpty) {
          await _change(ownerId, add: seen);
        }
        return Right(page);
    }
  }

  @override
  Future<Either<Failure, BlockList>> sync({required int ownerId}) async {
    final running = _syncing;
    if (running != null) {
      if (_syncingOwner == ownerId) return running;
      await running;
      return sync(ownerId: ownerId);
    }

    final future = _sync(ownerId);
    _syncing = future;
    _syncingOwner = ownerId;
    try {
      return await future;
    } finally {
      _syncing = null;
      _syncingOwner = null;
      _changedDuringSync.clear();
    }
  }

  Future<Either<Failure, BlockList>> _sync(int ownerId) async {
    final ids = <int>{};

    int? cursor;
    for (var pages = 0; ; pages++) {
      if (pages >= maxPages) return const Left(BlockListCursorFailure());

      final result = await _remote.fetchPage(
        limit: syncPageSize,
        afterTargetId: cursor,
      );

      final BlockedPage page;
      switch (result) {
        case Left(value: final failure):
          return Left(contactFailureFrom(failure));
        case Right(value: final value):
          page = value;
      }

      ids.addAll(page.users.map((user) => user.userId));
      if (!page.hasNext) break;

      final next = page.nextTargetId;
      if (next == null || (cursor != null && next <= cursor)) {
        Logger.warning(
          'Block list sync: cursor stuck at $cursor (next $next), giving up',
        );
        return const Left(BlockListCursorFailure());
      }
      cursor = next;
    }

    for (final MapEntry(key: id, value: blocked)
        in _changedDuringSync.entries) {
      blocked ? ids.add(id) : ids.remove(id);
    }

    final list = BlockList(ownerId: ownerId, userIds: ids);
    await _save(list);
    Logger.info('Block list sync: ${ids.length} blocked');
    return Right(list);
  }

  @override
  Future<Either<Failure, void>> block(
    int userId, {
    required int ownerId,
  }) async {
    final result = await _remote.block(userId);
    switch (result) {
      case Left(value: final failure):
        return Left(contactFailureFrom(failure));
      case Right():
        await _change(ownerId, add: {userId});
        return const Right(null);
    }
  }

  @override
  Future<Either<Failure, void>> unblock(
    int userId, {
    required int ownerId,
  }) async {
    final result = await _remote.unblock(userId);
    switch (result) {
      case Left(value: final failure):
        return Left(contactFailureFrom(failure));
      case Right():
        await _change(ownerId, remove: {userId});
        return const Right(null);
    }
  }

  @override
  Future<void> clear() => _local.clear();

  Future<void> _change(
    int ownerId, {
    Set<int> add = const <int>{},
    Set<int> remove = const <int>{},
  }) async {
    if (_syncing != null && _syncingOwner == ownerId) {
      for (final id in add) {
        _changedDuringSync[id] = true;
      }
      for (final id in remove) {
        _changedDuringSync[id] = false;
      }
    }

    final stored = _local.read();
    final base = stored != null && stored.ownerId == ownerId
        ? stored.userIds
        : const <int>{};
    await _save(
      BlockList(
        ownerId: ownerId,
        userIds: {...base, ...add}..removeAll(remove),
      ),
    );
  }

  Future<void> _save(BlockList list) {
    if (_local.read() == list) return Future.value();
    return _local.save(list);
  }
}

final blockedUsersRepositoryProvider = Provider<BlockedUsersRepository>(
  (ref) => BlockedUsersRepositoryImpl(
    remote: ref.watch(blockedUsersRemoteDataSourceProvider),
    local: ref.watch(blockListLocalStoreProvider),
  ),
);
