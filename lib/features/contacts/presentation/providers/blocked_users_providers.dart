import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/contacts/data/datasources/block_list_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/blocked_users_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/features/contacts/domain/usecases/block_use_cases.dart';
import 'package:chatix/features/notification/data/datasources/blocked_senders_store.dart';
import 'package:chatix/features/notification/domain/entities/blocked_senders.dart';

final blockUserUseCaseProvider = Provider<BlockUserUseCase>(
  (ref) => BlockUserUseCase(ref.watch(blockedUsersRepositoryProvider)),
);

final unblockUserUseCaseProvider = Provider<UnblockUserUseCase>(
  (ref) => UnblockUserUseCase(ref.watch(blockedUsersRepositoryProvider)),
);

final getBlockedPageUseCaseProvider = Provider<GetBlockedPageUseCase>(
  (ref) => GetBlockedPageUseCase(ref.watch(blockedUsersRepositoryProvider)),
);

final syncBlockListUseCaseProvider = Provider<SyncBlockListUseCase>(
  (ref) => SyncBlockListUseCase(ref.watch(blockedUsersRepositoryProvider)),
);

/// Who is blocked, as the app sees it.
class BlockListState extends Equatable {
  const BlockListState({
    this.userIds = const <int>{},
    this.isStored = false,
    this.busy = const <int>{},
  });

  final Set<int> userIds;

  /// Something was stored or read: an empty set is a real answer.
  final bool isStored;

  /// People whose block or unblock is on the wire right now, so a second tap
  /// does not send a second request.
  final Set<int> busy;

  BlockListState copyWith({Set<int>? userIds, bool? isStored, Set<int>? busy}) {
    return BlockListState(
      userIds: userIds ?? this.userIds,
      isStored: isStored ?? this.isStored,
      busy: busy ?? this.busy,
    );
  }

  @override
  List<Object?> get props => [userIds, isStored, busy];
}

/// The block list, from this device's copy, kept level with the server.
///
/// Like the contact book, [build] reads only the local store — no auth, no
/// network — so a chat header or a list row can ask "is this person
/// blocked?" without a request being made on its behalf, and gets the right
/// answer on the first frame.
///
/// A block and an unblock both show at once and are put back if the server
/// says no: the composer disappears the moment "Block" is confirmed, not a
/// round trip later.
class BlockListController extends Notifier<BlockListState> {
  @override
  BlockListState build() {
    final stored = ref.watch(blockListLocalStoreProvider).read();
    return BlockListState(
      userIds: stored?.userIds ?? const <int>{},
      isStored: stored != null,
    );
  }

  int? get _ownerId => ref.read(authProvider).value?.id;

  Future<void> sync() async {
    final ownerId = _ownerId;
    if (ownerId == null) return;

    final result = await ref
        .read(syncBlockListUseCaseProvider)
        .execute(ownerId: ownerId);
    if (!ref.mounted) return;

    // Signed out — or in as somebody else — while the pages were read.
    if (_ownerId != ownerId) {
      if (_ownerId == null) await forget();
      return;
    }

    result.match(
      (failure) => Logger.warning('Block list sync failed: ${failure.message}'),
      (_) => reload(),
    );
  }

  Future<Either<Failure, void>> block(int userId) =>
      _set(userId, blocked: true);

  Future<Either<Failure, void>> unblock(int userId) =>
      _set(userId, blocked: false);

  Future<Either<Failure, void>> _set(
    int userId, {
    required bool blocked,
  }) async {
    final ownerId = _ownerId;
    if (ownerId == null) return const Left(UnauthorizedFailure());
    if (state.busy.contains(userId)) return const Right(null);

    final before = state.userIds;
    state = state.copyWith(
      userIds: blocked ? {...before, userId} : ({...before}..remove(userId)),
      busy: {...state.busy, userId},
    );

    final result = blocked
        ? await ref
              .read(blockUserUseCaseProvider)
              .execute(userId, ownerId: ownerId)
        : await ref
              .read(unblockUserUseCaseProvider)
              .execute(userId, ownerId: ownerId);
    if (!ref.mounted) return result;

    final busy = {...state.busy}..remove(userId);
    state = result.match(
      (_) => state.copyWith(
        // Back as it was, for this person only: another block that landed
        // meanwhile stays.
        userIds: before.contains(userId)
            ? {...state.userIds, userId}
            : ({...state.userIds}..remove(userId)),
        busy: busy,
      ),
      (_) => state.copyWith(busy: busy, isStored: true),
    );
    return result;
  }

  /// Brings the state level with the store, which the repository writes
  /// every answer through to — pages read by the screen included.
  void reload() {
    if (!ref.mounted) return;
    final stored = ref.read(blockListLocalStoreProvider).read();
    if (stored == null) return;
    state = state.copyWith(userIds: stored.userIds, isStored: true);
  }

  /// Drops the list — the account it belonged to signed out.
  Future<void> forget() async {
    await ref.read(blockedUsersRepositoryProvider).clear();
    await ref.read(blockedSendersStoreProvider).save(BlockedSenders.none);
    if (!ref.mounted) return;
    state = const BlockListState();
  }
}

final blockListProvider = NotifierProvider<BlockListController, BlockListState>(
  BlockListController.new,
);

final blockedUserIdsProvider = Provider<Set<int>>(
  (ref) => ref.watch(blockListProvider.select((state) => state.userIds)),
);

/// Whether the owner blocked [userId]. Rebuilds only when that one answer
/// changes.
final isUserBlockedProvider = Provider.family<bool, int>(
  (ref, userId) => ref.watch(
    blockListProvider.select((state) => state.userIds.contains(userId)),
  ),
);

/// Whether a block or unblock of [userId] is on the wire.
final isBlockBusyProvider = Provider.family<bool, int>(
  (ref, userId) => ref.watch(
    blockListProvider.select((state) => state.busy.contains(userId)),
  ),
);

/// The direct chats whose other member is blocked, among the chats this
/// device has loaded.
///
/// Empty without a single block, and then it does not look at the chat list
/// at all — nothing that asks for this starts a fetch for nothing.
final blockedDirectChatIdsProvider = Provider<Set<String>>((ref) {
  final blocked = ref.watch(blockedUserIdsProvider);
  if (blocked.isEmpty) return const <String>{};

  final myUserId = ref.watch(authProvider.select((user) => user.value?.id));
  final rows = <ChatEntity>[
    ...?ref.watch(chatListProvider.select((state) => state.value?.items)),
    if (ref.exists(archivedChatListProvider))
      ...?ref.watch(
        archivedChatListProvider.select((state) => state.value?.items),
      ),
  ];

  return {
    for (final chat in rows)
      if (chat.peerUserId(myUserId) case final int peer
          when blocked.contains(peer))
        chat.id,
  };
});

/// What the notification presenter needs to recognise a blocked sender.
final blockedSendersProvider = Provider<BlockedSenders>((ref) {
  final userIds = ref.watch(blockedUserIdsProvider);
  if (userIds.isEmpty) return BlockedSenders.none;
  return BlockedSenders(
    userIds: userIds,
    directChatIds: ref.watch(blockedDirectChatIdsProvider),
  );
});

/// Writes [blockedSendersProvider] where a push drawn with the app closed
/// can read it. Watched by the shell, which is up whenever somebody is
/// signed in and already keeps the chat list alive.
final blockedSendersSnapshotProvider = Provider<void>((ref) {
  final store = ref.watch(blockedSendersStoreProvider);
  ref.listen<BlockedSenders>(blockedSendersProvider, (previous, next) {
    if (previous == next) return;
    unawaited(store.save(next));
  }, fireImmediately: true);
});

/// Keeps the block list in step with the session, from the top of the app:
/// read again at launch and at sign-in, thrown away at sign-out.
final blockListLifecycleProvider = Provider<void>((ref) {
  var wasSignedIn = ref.read(authProvider).value != null;

  void sync() => unawaited(ref.read(blockListProvider.notifier).sync());

  // Not during this build: a provider may not change another while it is
  // being created.
  if (wasSignedIn) scheduleMicrotask(sync);

  ref.listen(authProvider, (_, next) {
    if (next.isLoading) return;

    final signedIn = next.hasValue && next.value != null;
    final signedOut = wasSignedIn && !signedIn;
    final signedInNow = !wasSignedIn && signedIn;
    wasSignedIn = signedIn;

    if (signedOut) {
      unawaited(ref.read(blockListProvider.notifier).forget());
    } else if (signedInNow) {
      sync();
    }
  });
}, dependencies: [authProvider]);

/// The block list screen: who is blocked, a page at a time.
class BlockedUsersListState extends Equatable {
  const BlockedUsersListState({
    this.users = const <BlockedUser>[],
    this.hasNext = false,
    this.nextTargetId,
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  /// Every row read so far, in the server's order. Who is still blocked is
  /// [blockedUserIdsProvider]'s answer: the screen shows the intersection, so
  /// an unblock takes its row away at once and a refused one brings it back.
  final List<BlockedUser> users;

  final bool hasNext;
  final int? nextTargetId;
  final bool isLoadingMore;

  /// Why the last "more" failed; the footer offers to try again.
  final Failure? loadMoreFailure;

  bool get canLoadMore => hasNext && nextTargetId != null && !isLoadingMore;

  BlockedUsersListState copyWith({
    List<BlockedUser>? users,
    bool? hasNext,
    int? Function()? nextTargetId,
    bool? isLoadingMore,
    Failure? Function()? loadMoreFailure,
  }) {
    return BlockedUsersListState(
      users: users ?? this.users,
      hasNext: hasNext ?? this.hasNext,
      nextTargetId: nextTargetId == null ? this.nextTargetId : nextTargetId(),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailure: loadMoreFailure == null
          ? this.loadMoreFailure
          : loadMoreFailure(),
    );
  }

  @override
  List<Object?> get props => [
    users,
    hasNext,
    nextTargetId,
    isLoadingMore,
    loadMoreFailure,
  ];
}

class BlockedUsersListController extends AsyncNotifier<BlockedUsersListState> {
  @override
  Future<BlockedUsersListState> build() async {
    final ownerId = ref.watch(authProvider.select((user) => user.value?.id));
    if (ownerId == null) return const BlockedUsersListState();
    return _firstPage(ownerId);
  }

  Future<BlockedUsersListState> _firstPage(int ownerId) async {
    final result = await ref
        .read(getBlockedPageUseCaseProvider)
        .execute(ownerId: ownerId);
    final page = result.getOrElse((failure) => throw failure);

    // The repository has written who was on the page; the rest of the app
    // should agree before the rows are drawn against it.
    ref.read(blockListProvider.notifier).reload();

    return BlockedUsersListState(
      users: page.users,
      hasNext: page.hasNext,
      nextTargetId: page.nextTargetId,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    final ownerId = ref.read(authProvider).value?.id;
    if (current == null || ownerId == null || !current.canLoadMore) return;

    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailure: () => null),
    );

    final result = await ref
        .read(getBlockedPageUseCaseProvider)
        .execute(ownerId: ownerId, afterTargetId: current.nextTargetId);
    if (!ref.mounted) return;

    final latest = state.value ?? current;
    state = AsyncData(
      result.match(
        (failure) => latest.copyWith(
          isLoadingMore: false,
          loadMoreFailure: () => failure,
        ),
        (page) {
          final known = {for (final user in latest.users) user.userId};
          return latest.copyWith(
            users: [
              ...latest.users,
              for (final user in page.users)
                if (!known.contains(user.userId)) user,
            ],
            hasNext: page.hasNext,
            nextTargetId: () => page.nextTargetId,
            isLoadingMore: false,
          );
        },
      ),
    );
    ref.read(blockListProvider.notifier).reload();
  }

  /// From the first page again — and the whole list behind it, so an
  /// unblock made on another device leaves this one too.
  ///
  /// A refresh that fails keeps the rows already on screen: the list was
  /// right a moment ago, and a spinner that ends is answer enough.
  Future<void> refresh() async {
    final ownerId = ref.read(authProvider).value?.id;
    if (ownerId == null) return;

    unawaited(ref.read(blockListProvider.notifier).sync());
    final next = await AsyncValue.guard(() => _firstPage(ownerId));
    if (!ref.mounted) return;
    if (next.hasError && state.hasValue) return;
    state = next;
  }
}

final blockedUsersListProvider =
    AsyncNotifierProvider<BlockedUsersListController, BlockedUsersListState>(
      BlockedUsersListController.new,
      isAutoDispose: true,
    );

/// How many people the screen can say are blocked: this device's copy,
/// which every page read and every block keeps up to date. Null until
/// anything has been stored.
final blockedCountProvider = Provider<int?>((ref) {
  final state = ref.watch(blockListProvider);
  return state.isStored ? state.userIds.length : null;
});
