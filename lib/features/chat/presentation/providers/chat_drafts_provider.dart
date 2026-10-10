import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/models/chat_draft_model.dart';
import 'package:chatix/features/chat/domain/entities/chat_draft.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_state_actions.dart';

/// What the drafts read the time from — the device clock, unless a test
/// needs another.
final chatDraftClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Message text typed into a chat and left there — on this device and on the
/// account.
///
/// The server keeps a draft per chat (`ChatDTO.draft`, written through
/// `PATCH /chats/{id}/state/ {draft}`, api-docs §5.2), so a draft typed on a
/// phone is there on the desktop. This is the device's copy of it: what the
/// composer reads back without waiting, what the chat list draws before the
/// network answers, and the queue of writes the server has not had yet.
///
/// Two copies disagree when two devices typed, or one typed offline. The
/// newer `draft_updated_at` wins ([ChatDraftMerge]); [reconcile] applies that
/// whenever the chat list brings the server's copies in.
///
/// Writing is gentle with the endpoint: a burst of typing is one request
/// [serverWriteDelay] after the last keystroke, never more than the shared
/// limit allows ([chatStateWriteLimiterProvider]), and one at a time per
/// chat.
class ChatDraftsController extends Notifier<Map<String, ChatDraft>> {
  /// Long enough that a burst of typing is one write to disk, short enough
  /// that a draft survives the app being killed a moment after you stop.
  static const Duration writeDelay = Duration(milliseconds: 600);

  /// The quiet after the last keystroke before the server hears about it.
  static const Duration serverWriteDelay = Duration(milliseconds: 1500);

  /// Before a write that failed for want of a network is tried again.
  static const Duration retryDelay = Duration(seconds: 30);

  /// Slots of the endpoint's minute that drafts never take, so pinning or
  /// muting a chat is not the request that gets a 429.
  static const int reservedForOthers = 10;

  Timer? _writeTimer;
  final Map<String, Timer> _syncTimers = {};
  final Set<String> _inFlight = {};

  /// The server's copy, as last seen — from the chat list or from the answer
  /// to a write.
  final Map<String, ServerDraft> _server = {};

  DateTime _now() => ref.read(chatDraftClockProvider)();

  @override
  Map<String, ChatDraft> build() {
    ref.onDispose(() {
      _writeTimer?.cancel();
      _writeTimer = null;
      for (final timer in _syncTimers.values) {
        timer.cancel();
      }
      _syncTimers.clear();
    });

    final store = ref.watch(chatLocalDataSourceProvider);
    final stored = store.readDrafts();
    if (stored.isNotEmpty) return _decodeAll(stored);

    // Drafts used to live in shared preferences, next to the recent emoji
    // that still do. An install that predates the chat store has them there
    // and nowhere else, so they are read across once — the first write
    // below puts them in their new home.
    final inherited = ref.read(chatLocalPrefsStoreProvider).readDrafts();
    if (inherited.isNotEmpty) unawaited(store.writeDrafts(inherited));

    return _decodeAll(inherited);
  }

  static Map<String, ChatDraft> _decodeAll(Map<String, String> raw) => {
    for (final entry in raw.entries)
      entry.key: ?ChatDraftCodec.decode(entry.value),
  };

  /// The draft to put in the composer, or null when there is none.
  String? of(String chatId) {
    final draft = state[chatId];
    return draft == null || draft.isCleared ? null : draft.text;
  }

  /// Stores what is in the composer. Blank text means there is no draft.
  void save(String chatId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      clear(chatId);
      return;
    }

    final current = state[chatId];
    if (current?.text == trimmed) return;

    _put(
      chatId,
      ChatDraft(
        text: trimmed,
        updatedAt: _now(),
        syncedAt: current?.syncedAt,
        pending: true,
      ),
    );
    _schedulePersist();
    _scheduleSync(chatId, serverWriteDelay);
  }

  /// There is no draft any more — it was sent, or erased.
  ///
  /// Kept as an empty marker until the server has been told, so a list
  /// fetched in between cannot bring the old text back.
  void clear(String chatId) {
    final current = state[chatId];
    if (current == null || current.isCleared) return;

    // Typed here and never written anywhere, in a chat the server is known
    // to hold no draft for: there is nobody to tell.
    final server = _server[chatId];
    if (current.syncedAt == null &&
        server != null &&
        server.normalized.isEmpty) {
      _cancelSync(chatId);
      _remove(chatId);
      _schedulePersist();
      return;
    }

    _put(
      chatId,
      ChatDraft(
        text: '',
        updatedAt: _now(),
        syncedAt: current.syncedAt,
        pending: true,
      ),
    );
    _schedulePersist();
    _scheduleSync(chatId, serverWriteDelay);
  }

  /// Takes in the server's copies, from rows of the chat list.
  ///
  /// For each chat the newer draft wins: the server's replaces this
  /// device's, or this device's is (re)scheduled to be written. Rows that
  /// carry no state — `ChatDetailDTO` has none — say nothing either way.
  void reconcile(Iterable<ChatEntity> chats) {
    var next = state;
    var changed = false;

    for (final chat in chats) {
      final server = ServerDraft.of(chat.state);
      if (server == null) continue;
      _server[chat.id] = server;

      final local = next[chat.id];
      final winner = ChatDraftMerge.winner(local: local, server: server);

      if (winner == DraftSide.server) {
        _cancelSync(chat.id);

        final text = server.normalized;
        final adopted = text.isEmpty
            ? null
            : ChatDraft(
                text: text,
                updatedAt: server.updatedAt ?? _now(),
                syncedAt: server.updatedAt,
              );
        if (adopted != local) {
          next = adopted == null
              ? _without(next, chat.id)
              : {...next, chat.id: adopted};
          changed = true;
        }
        continue;
      }

      if (local == null) continue;

      if (local.text == server.normalized) {
        // Both sides already agree.
        _cancelSync(chat.id);
        if (local.isCleared) {
          next = _without(next, chat.id);
          changed = true;
        } else if (local.pending || local.syncedAt != server.updatedAt) {
          next = {
            ...next,
            chat.id: local.copyWith(pending: false, syncedAt: server.updatedAt),
          };
          changed = true;
        }
        continue;
      }

      // This device's draft is the newer one and the server has something
      // else. A row older than the version already agreed on is only a stale
      // copy — the server has had this draft since.
      final serverAt = server.updatedAt;
      final agreedAt = local.syncedAt;
      if (!local.pending &&
          serverAt != null &&
          agreedAt != null &&
          !serverAt.isAfter(agreedAt)) {
        continue;
      }

      if (!local.pending) {
        next = {...next, chat.id: local.copyWith(pending: true)};
        changed = true;
      }
      _scheduleSync(chat.id, serverWriteDelay);
    }

    if (changed) {
      state = next;
      unawaited(_persist());
    }
  }

  /// Writes to disk now instead of waiting out the debounce, and sends what
  /// the server has not had — what leaving a chat screen does, so the draft
  /// is on disk and on its way before the screen is gone.
  Future<void> flush() async {
    _writeTimer?.cancel();
    _writeTimer = null;

    // Started here rather than on a zero-length timer: a screen that is
    // going away should not leave a timer behind to do it.
    for (final chatId in [..._syncTimers.keys]) {
      _cancelSync(chatId);
      unawaited(_sync(chatId));
    }

    await _persist();
  }

  // ---------------------------------------------------------------- server

  void _scheduleSync(String chatId, Duration delay) {
    _syncTimers.remove(chatId)?.cancel();
    _syncTimers[chatId] = Timer(delay, () {
      _syncTimers.remove(chatId);
      unawaited(_sync(chatId));
    });
  }

  void _cancelSync(String chatId) => _syncTimers.remove(chatId)?.cancel();

  Future<void> _sync(String chatId) async {
    if (!ref.mounted) return;

    final draft = state[chatId];
    if (draft == null || !draft.pending) return;

    // One write per chat at a time: the answer to the first decides what
    // the second has to say.
    if (_inFlight.contains(chatId)) {
      _scheduleSync(chatId, serverWriteDelay);
      return;
    }

    // Exactly what the server already holds: nothing to write.
    final known = _server[chatId];
    if (known != null && known.normalized == draft.text) {
      _settle(chatId, sent: draft, serverAt: known.updatedAt);
      return;
    }

    final limiter = ref.read(chatStateWriteLimiterProvider);
    final wait = limiter.delayFor(_now(), reserve: reservedForOthers);
    if (wait > Duration.zero) {
      _scheduleSync(chatId, wait);
      return;
    }

    limiter.record(_now());
    _inFlight.add(chatId);

    final Either<Failure, ChatStateEntity> result;
    try {
      result = await ref
          .read(updateChatStateUseCaseProvider)
          .setDraft(chatId, draft.isCleared ? null : draft.text);
    } catch (error, stackTrace) {
      // Not a failure the server reported: something on this side broke,
      // and a timer would only break it again. The draft stays pending and
      // goes up with the next edit or the next list fetch.
      _inFlight.remove(chatId);
      Logger.error('Chat drafts: $chatId not written', error, stackTrace);
      return;
    }

    _inFlight.remove(chatId);
    if (!ref.mounted) return;

    result.match((failure) => _onSyncFailed(chatId, draft, failure), (
      serverState,
    ) {
      _server[chatId] = ServerDraft(
        text: serverState.draft,
        updatedAt: serverState.draftUpdatedAt,
      );
      ref.read(chatStateActionsProvider).absorb(chatId, serverState);
      _settle(chatId, sent: draft, serverAt: serverState.draftUpdatedAt);
    });
  }

  /// The server holds [sent] as of [serverAt].
  void _settle(
    String chatId, {
    required ChatDraft sent,
    required DateTime? serverAt,
  }) {
    final current = state[chatId];
    if (current == null) return;

    if (current != sent) {
      // Typed on while the write was out: the newer text is still pending
      // and already scheduled; it is now newer than this server version.
      _put(chatId, current.copyWith(syncedAt: serverAt));
    } else if (sent.isCleared) {
      _remove(chatId);
    } else {
      _put(chatId, current.copyWith(pending: false, syncedAt: serverAt));
    }
    // Straight to disk: these come at most once a write, and a debounce
    // here would only be one more timer outliving the screen that typed.
    unawaited(_persist());
  }

  void _onSyncFailed(String chatId, ChatDraft sent, Failure failure) {
    Logger.warning('Chat drafts: $chatId not saved (${failure.message})');

    switch (failure) {
      // The server's count disagreed with ours. It is the one that counts.
      case RateLimitFailure():
        final limiter = ref.read(chatStateWriteLimiterProvider);
        limiter.blockFor(_now());
        _scheduleSync(chatId, limiter.delayFor(_now()));

      // No network, or none that answered: the draft is safe here, and goes
      // up when it can.
      case NetworkFailure() || TimeoutFailure() || ServerFailure():
        _scheduleSync(chatId, retryDelay);
      case ApiFailure(:final status) when status >= 500:
        _scheduleSync(chatId, retryDelay);

      // The server will not take it as it is — the chat is gone, this
      // reader left it, the text is over the cap. Retrying would only fail
      // again; what was typed stays on this device.
      default:
        final current = state[chatId];
        if (current != sent) return;
        if (sent.isCleared) {
          _remove(chatId);
        } else {
          _put(chatId, current!.copyWith(pending: false));
        }
        unawaited(_persist());
    }
  }

  // ------------------------------------------------------------------ disk

  void _put(String chatId, ChatDraft draft) {
    if (state[chatId] == draft) return;
    state = {...state, chatId: draft};
  }

  void _remove(String chatId) {
    if (!state.containsKey(chatId)) return;
    state = _without(state, chatId);
  }

  static Map<String, ChatDraft> _without(
    Map<String, ChatDraft> drafts,
    String chatId,
  ) => {
    for (final entry in drafts.entries)
      if (entry.key != chatId) entry.key: entry.value,
  };

  void _schedulePersist() {
    _writeTimer?.cancel();
    _writeTimer = Timer(writeDelay, () {
      _writeTimer = null;
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    try {
      await ref.read(chatLocalDataSourceProvider).writeDrafts({
        for (final entry in state.entries)
          entry.key: ChatDraftCodec.encode(entry.value),
      });
    } catch (error) {
      Logger.warning('Chat drafts: not persisted ($error)');
    }
  }
}

final chatDraftsProvider =
    NotifierProvider<ChatDraftsController, Map<String, ChatDraft>>(
      ChatDraftsController.new,
    );

/// This device's copy of one chat's draft, without rebuilding a row every
/// time some other chat's draft changes. The row merges it with the
/// server's copy it carries ([ChatDraftMerge.textOf]).
final chatDraftEntryProvider = Provider.family<ChatDraft?, String>((
  ref,
  chatId,
) {
  return ref.watch(chatDraftsProvider.select((drafts) => drafts[chatId]));
});
