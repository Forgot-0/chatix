import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_state_failures.dart';
import 'package:chatix/features/chat/domain/usecases/update_chat_state_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

/// Pinning, archiving and silencing, from wherever a chat row is drawn.
///
/// All three are one endpoint — `PATCH /chats/{chat_id}/state/` — and all
/// three used to be shared preferences. They are on the server now, which
/// means two things for the UI: the row's own flags are the truth, and a
/// failed write has to put the row back the way it was.
class ChatStateActions {
  const ChatStateActions(this._ref);

  final Ref _ref;

  UpdateChatStateUseCase get _useCase =>
      _ref.read(updateChatStateUseCaseProvider);

  /// Pins a chat or lets it go.
  ///
  /// Refuses a sixth pin before asking, because the server would refuse it
  /// too and the reader deserves to hear which limit they hit rather than a
  /// round trip's worth of nothing.
  Future<Failure?> setPinned(String chatId, {required bool pinned}) async {
    if (pinned && _pinnedCount() >= UpdateChatStateUseCase.pinnedLimit) {
      return const PinnedChatsLimitFailure(
        limit: UpdateChatStateUseCase.pinnedLimit,
      );
    }

    final now = DateTime.now();

    return _write(
      chatId,
      optimistic: (state) => state.copyWith(
        isPinned: pinned,
        pinnedAt: pinned ? now : null,
        clearPinnedAt: !pinned,
      ),
      call: () => _useCase.setPinned(chatId, pinned: pinned),
    );
  }

  Future<Failure?> togglePinned(ChatEntity chat) =>
      setPinned(chat.id, pinned: !chat.isPinned);

  /// Moves a chat between the list and the archive.
  ///
  /// The two are separate sets on the server, so this is a move rather than
  /// a flag: the row leaves one list and joins the other at once, and goes
  /// back where it came from if the write fails.
  Future<Failure?> setArchived(
    String chatId, {
    required bool archived,
  }) async {
    final from = archived ? chatListProvider : archivedChatListProvider;
    final to = archived ? archivedChatListProvider : chatListProvider;

    final row = _ref.read(from.notifier).rowOf(chatId);

    final moved = row?.copyWith(
      state: (row.state ?? const ChatStateEntity()).copyWith(
        isArchived: archived,
      ),
    );

    if (moved != null) {
      _ref.read(from.notifier).removeLocally(chatId);
      if (_ref.exists(to)) _ref.read(to.notifier).adoptRow(moved);
    }

    final result = await _useCase.setArchived(chatId, archived: archived);

    return result.match((failure) {
      Logger.warning(
        'ChatState: $chatId not ${archived ? 'archived' : 'unarchived'} '
        '(${failure.message})',
      );

      if (row != null) {
        if (_ref.exists(to)) _ref.read(to.notifier).removeLocally(chatId);
        _ref.read(from.notifier).adoptRow(row);
      }

      return failure;
    }, (_) => null);
  }

  Future<Failure?> toggleArchived(ChatEntity chat) =>
      setArchived(chat.id, archived: !chat.isArchived);

  /// Silences a chat, or lets it speak again.
  ///
  /// Silence has a deadline rather than a switch: "forever" is a date far
  /// enough out that nobody reaches it, which is how the field is shaped.
  Future<Failure?> setMuted(
    String chatId, {
    required bool muted,
    DateTime? until,
  }) {
    return _write(
      chatId,
      optimistic: (state) => state.copyWith(
        isMutedByMe: muted,
        notificationsMutedUntil: muted ? until : null,
        clearMutedUntil: !muted,
      ),
      call: () =>
          muted ? _useCase.mute(chatId, until: until) : _useCase.unmute(chatId),
    );
  }

  Future<Failure?> toggleMuted(ChatEntity chat, {DateTime? until}) =>
      setMuted(chat.id, muted: !chat.isMutedByMe, until: until);

  /// Applies [optimistic] to whichever list holds the row, runs [call], and
  /// puts the row back if the server disagrees.
  Future<Failure?> _write(
    String chatId, {
    required ChatStateEntity Function(ChatStateEntity state) optimistic,
    required Future<Either<Failure, ChatStateEntity>> Function() call,
  }) async {
    final rollbacks = <ChatEntity>[];

    for (final provider in _liveLists()) {
      final before = _ref.read(provider.notifier).patchState(chatId, optimistic);
      if (before != null) rollbacks.add(before);
    }

    final result = await call();

    return result.match(
      (failure) {
        Logger.warning(
          'ChatState: $chatId not updated (${failure.message})',
        );
        for (final provider in _liveLists()) {
          for (final row in rollbacks) {
            _ref.read(provider.notifier).restoreRow(row);
          }
        }
        return _asDomainFailure(failure);
      },
      (state) {
        // The server's own reading wins: it knows whether a mute deadline
        // has already passed, and this device's clock may not.
        for (final provider in _liveLists()) {
          _ref.read(provider.notifier).patchState(chatId, (_) => state);
        }
        return null;
      },
    );
  }

  /// The lists that are on screen. Reading a provider that is not alive
  /// would start it, which for the archive means a request nobody asked for.
  List<AsyncNotifierProvider<ChatListController, ChatListState>> _liveLists() {
    return [
      if (_ref.exists(chatListProvider)) chatListProvider,
      if (_ref.exists(archivedChatListProvider)) archivedChatListProvider,
    ];
  }

  int _pinnedCount() {
    final seen = <String>{};
    var total = 0;

    for (final provider in _liveLists()) {
      final items = _ref.read(provider).value?.items ?? const <ChatEntity>[];
      for (final chat in items) {
        if (!chat.isPinned) continue;
        if (!seen.add(chat.id)) continue;
        total++;
      }
    }

    return total;
  }

  /// Turns the server's own refusal into the failure the UI already knows
  /// how to explain.
  Failure _asDomainFailure(Failure failure) {
    if (failure is ApiFailure && failure.code == 'PINNED_CHATS_LIMIT_EXCEEDED') {
      final detail = failure.detail;
      final limit = detail is Map<String, dynamic> ? detail['limit'] : null;
      return PinnedChatsLimitFailure(
        limit: limit is int ? limit : UpdateChatStateUseCase.pinnedLimit,
      );
    }
    return failure;
  }
}

final chatStateActionsProvider = Provider<ChatStateActions>(
  ChatStateActions.new,
);
