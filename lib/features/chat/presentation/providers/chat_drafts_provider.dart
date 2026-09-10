import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';

/// Message text typed into a chat and left there.
///
/// The API has nowhere to put an unsent message, so a draft is this device's
/// business alone: the composer writes into it as you type, the chat list
/// reads it back as the row's preview, and sending clears it.
class ChatDraftsController extends Notifier<Map<String, String>> {
  /// Long enough that a burst of typing is one write, short enough that a
  /// draft survives the app being killed a moment after you stop.
  static const Duration writeDelay = Duration(milliseconds: 600);

  Timer? _writeTimer;

  @override
  Map<String, String> build() {
    ref.onDispose(() {
      _writeTimer?.cancel();
      _writeTimer = null;
    });

    return ref.watch(chatLocalPrefsStoreProvider).readDrafts();
  }

  String? of(String chatId) => state[chatId];

  /// Stores what is in the composer. Blank text means there is no draft.
  void save(String chatId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      clear(chatId);
      return;
    }
    if (state[chatId] == trimmed) return;

    state = {...state, chatId: trimmed};
    _schedulePersist();
  }

  void clear(String chatId) {
    if (!state.containsKey(chatId)) return;

    state = {
      for (final entry in state.entries)
        if (entry.key != chatId) entry.key: entry.value,
    };
    _schedulePersist();
  }

  /// Writes now instead of waiting out the debounce — what leaving a chat
  /// screen does, so a draft is on disk before the screen is gone.
  Future<void> flush() async {
    _writeTimer?.cancel();
    _writeTimer = null;
    await _persist();
  }

  void _schedulePersist() {
    _writeTimer?.cancel();
    _writeTimer = Timer(writeDelay, () {
      _writeTimer = null;
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    try {
      await ref.read(chatLocalPrefsStoreProvider).writeDrafts(state);
    } catch (error) {
      Logger.warning('Chat drafts: not persisted ($error)');
    }
  }
}

final chatDraftsProvider =
    NotifierProvider<ChatDraftsController, Map<String, String>>(
      ChatDraftsController.new,
    );

/// The draft for one chat, without rebuilding a row every time some other
/// chat's draft changes.
final chatDraftProvider = Provider.family<String?, String>((ref, chatId) {
  return ref.watch(chatDraftsProvider.select((drafts) => drafts[chatId]));
});
