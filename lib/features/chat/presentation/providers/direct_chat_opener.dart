import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_chats_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/utils/direct_chat_lookup.dart';

/// Finds the 1:1 chat with a person, and creates it only when there truly is
/// none.
///
/// The backend will not stop a duplicate: `409 DIRECT_CHAT_EXISTS` is
/// documented but never raised, so a second `POST /chats/` quietly makes a
/// second chat (api-docs §5.2). Everything that guards against that is here,
/// in the order it costs:
///
/// 1. the chats this device has on screen — the main list and, when it has
///    been opened, the archive;
/// 2. both lists as this device last saved them;
/// 3. a chat this opener made or found earlier in the session, which the
///    list may not have caught up with yet;
/// 4. the server: whatever of the main list was never paged in, and the
///    whole archive — an archived chat is not in the main list at all, and a
///    cached copy can be older than the chat;
/// 5. only then a create, and `DIRECT_CHAT_EXISTS` still read back in case
///    the server ever starts answering it.
///
/// Two taps on the same person share one lookup, so a double tap cannot race
/// two creates. And when the server cannot be asked, the answer is the
/// failure, not a create: a chat that may already exist is not made again.
class DirectChatOpener {
  DirectChatOpener(this._ref);

  final Ref _ref;

  /// Lookups still running, by the other person's user id.
  final Map<int, Future<Either<Failure, String>>> _pending = {};

  /// Chats made or found by a server walk this session, by user id.
  final Map<int, String> _known = {};

  /// How many pages of each list a walk may read before it gives up and
  /// treats the person as having no chat. 50 × 100 is far beyond any real
  /// account, and still a bound.
  static const int maxScanPages = 50;

  /// The id of the chat with [userId], created if need be.
  Future<Either<Failure, String>> resolve(int userId) {
    final pending = _pending[userId];
    if (pending != null) return pending;

    final lookup = _resolve(userId);
    _pending[userId] = lookup;
    // Removed once settled, whichever way, so a later tap asks again.
    unawaited(lookup.whenComplete(() => _pending.remove(userId)));
    return lookup;
  }

  Future<Either<Failure, String>> _resolve(int userId) async {
    final myUserId = _ref.read(authProvider).value?.id;

    final onDevice = _findOnDevice(userId, myUserId);
    if (onDevice != null) return Right(onDevice);

    final known = _known[userId];
    if (known != null) return Right(known);

    final scanned = await _scanServer(userId, myUserId);
    if (!_ref.mounted) return const Left(CancelledFailure());

    final failure = scanned.getLeft().toNullable();
    if (failure != null) return Left(failure);

    final found = scanned.getRight().toNullable();
    if (found != null) {
      _known[userId] = found;
      return Right(found);
    }

    final created = await _ref
        .read(createChatUseCaseProvider)
        .execute(chatType: ChatType.direct, memberIds: [userId]);
    if (!_ref.mounted) return const Left(CancelledFailure());

    return created.match<Either<Failure, String>>(
      (failure) {
        final chatId = existingDirectChatId(failure);
        if (chatId == null) return Left(failure);
        _remember(userId, chatId);
        return Right(chatId);
      },
      (chat) {
        _remember(userId, chat.id);
        return Right(chat.id);
      },
    );
  }

  void _remember(int userId, String chatId) {
    _known[userId] = chatId;
    unawaited(_ref.read(chatListProvider.notifier).refresh());
  }

  String? _findOnDevice(int userId, int? myUserId) {
    final local = _ref.read(getLocalChatsUseCaseProvider);

    final sources = <Iterable<ChatEntity>>[
      _ref.read(chatListProvider).value?.items ?? const [],
      if (_ref.exists(archivedChatListProvider))
        _ref.read(archivedChatListProvider).value?.items ?? const [],
      local.execute()?.chats ?? const [],
      local.execute(archived: true)?.chats ?? const [],
    ];

    for (final chats in sources) {
      final chat = findDirectChatWith(chats, userId, myUserId: myUserId);
      if (chat != null) return chat.id;
    }
    return null;
  }

  /// Reads whatever this device has not seen of the two lists.
  ///
  /// The main list resumes from the cursor of the pages already on screen;
  /// the archive is read from its start unless it is on screen in full.
  Future<Either<Failure, String?>> _scanServer(
    int userId,
    int? myUserId,
  ) async {
    final main = _ref.read(chatListProvider).value;
    if (main == null || main.canLoadMore) {
      final found = await _walk(
        userId,
        myUserId,
        archived: false,
        from: main == null
            ? null
            : ChatsPage(
                chats: const [],
                hasNext: main.hasNext,
                nextDate: main.nextDate,
                nextChatId: main.nextChatId,
              ),
      );
      if (found.isLeft() || found.getRight().toNullable() != null) {
        return found;
      }
    }

    final archive = _ref.exists(archivedChatListProvider)
        ? _ref.read(archivedChatListProvider).value
        : null;
    if (archive != null && !archive.canLoadMore) return const Right(null);

    return _walk(userId, myUserId, archived: true);
  }

  Future<Either<Failure, String?>> _walk(
    int userId,
    int? myUserId, {
    required bool archived,
    ChatsPage? from,
  }) async {
    final getChats = _ref.read(getChatsUseCaseProvider);
    var page = from;

    for (var read = 0; read < maxScanPages; read++) {
      final result = page == null
          ? await getChats.execute(
              limit: GetChatsUseCase.maxLimit,
              archived: archived,
            )
          : await getChats.executeNextPage(
              page,
              limit: GetChatsUseCase.maxLimit,
              archived: archived,
            );
      if (!_ref.mounted) return const Left(CancelledFailure());

      final failure = result.getLeft().toNullable();
      if (failure != null) return Left(failure);

      final next = result.getRight().toNullable()!;
      final chat = findDirectChatWith(next.chats, userId, myUserId: myUserId);
      if (chat != null) return Right(chat.id);
      if (!next.canLoadMore) return const Right(null);
      page = next;
    }

    return const Right(null);
  }
}

/// One opener per signed-in account: what it remembers about who has a
/// chat belongs to that account, and is dropped with it.
final directChatOpenerProvider = Provider<DirectChatOpener>((ref) {
  ref.watch(authProvider.select((user) => user.value?.id));
  return DirectChatOpener(ref);
});

/// The id of the 1:1 chat with [userId], creating it if there is none —
/// see [DirectChatOpener] for how hard "none" is checked.
Future<Either<Failure, String>> resolveDirectChatWith(
  WidgetRef ref,
  int userId,
) => ref.read(directChatOpenerProvider).resolve(userId);
