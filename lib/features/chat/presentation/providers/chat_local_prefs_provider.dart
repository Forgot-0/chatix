import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';

/// The store behind the device-local chat flags and drafts.
///
/// Shared preferences are handed to the app at startup, so anywhere they were
/// not — a widget test that pumps the list without overriding them — this
/// falls back to memory rather than taking the screen down with it.
final chatLocalPrefsStoreProvider = Provider<ChatLocalPrefsStore>((ref) {
  try {
    return SharedPrefsChatLocalPrefsStore(
      ref.watch(localStorageServiceProvider),
    );
  } catch (error) {
    Logger.debug('Chat prefs: no persistent storage, keeping them in memory');
    return InMemoryChatLocalPrefsStore();
  }
});

/// Which chats this device pins, archives and silences.
class ChatLocalPrefs extends Equatable {
  const ChatLocalPrefs({
    this.pinned = const <String>{},
    this.archived = const <String>{},
    this.muted = const <String>{},
  });

  /// Kept above everything else in the list, newest pin first is not a thing:
  /// pins keep the list's own ordering among themselves.
  final Set<String> pinned;

  /// Hidden from the main list and reachable through the archive section.
  final Set<String> archived;

  /// Notifications off. Not `MemberChatDTO.is_muted`, which is the moderator
  /// mute that stops a member writing.
  final Set<String> muted;

  bool isPinned(String chatId) => pinned.contains(chatId);

  bool isArchived(String chatId) => archived.contains(chatId);

  bool isMuted(String chatId) => muted.contains(chatId);

  Set<String> of(ChatLocalFlag flag) => switch (flag) {
    ChatLocalFlag.pinned => pinned,
    ChatLocalFlag.archived => archived,
    ChatLocalFlag.muted => muted,
  };

  ChatLocalPrefs withFlag(ChatLocalFlag flag, Set<String> chatIds) {
    return switch (flag) {
      ChatLocalFlag.pinned => ChatLocalPrefs(
        pinned: chatIds,
        archived: archived,
        muted: muted,
      ),
      ChatLocalFlag.archived => ChatLocalPrefs(
        pinned: pinned,
        archived: chatIds,
        muted: muted,
      ),
      ChatLocalFlag.muted => ChatLocalPrefs(
        pinned: pinned,
        archived: archived,
        muted: chatIds,
      ),
    };
  }

  @override
  List<Object?> get props => [pinned, archived, muted];
}

class ChatLocalPrefsController extends Notifier<ChatLocalPrefs> {
  @override
  ChatLocalPrefs build() {
    final store = ref.watch(chatLocalPrefsStoreProvider);
    return ChatLocalPrefs(
      pinned: store.readFlag(ChatLocalFlag.pinned),
      archived: store.readFlag(ChatLocalFlag.archived),
      muted: store.readFlag(ChatLocalFlag.muted),
    );
  }

  /// Turns [flag] on or off for [chatId] and reports what it now is.
  bool toggle(ChatLocalFlag flag, String chatId) {
    final current = state.of(flag);
    final next = current.contains(chatId)
        ? (current.where((id) => id != chatId).toSet())
        : {...current, chatId};

    _write(flag, next);
    return next.contains(chatId);
  }

  void set(ChatLocalFlag flag, String chatId, {required bool value}) {
    final current = state.of(flag);
    if (current.contains(chatId) == value) return;

    _write(
      flag,
      value
          ? {...current, chatId}
          : current.where((id) => id != chatId).toSet(),
    );
  }

  /// Drops every flag a chat carried — what deleting or leaving it means for
  /// state that only exists here.
  void forget(String chatId) {
    for (final flag in ChatLocalFlag.values) {
      set(flag, chatId, value: false);
    }
  }

  void _write(ChatLocalFlag flag, Set<String> chatIds) {
    state = state.withFlag(flag, chatIds);

    unawaited(
      ref
          .read(chatLocalPrefsStoreProvider)
          .writeFlag(flag, chatIds)
          .catchError(
            (Object error) =>
                Logger.warning('Chat prefs: flag not persisted ($error)'),
          ),
    );
  }
}

final chatLocalPrefsProvider =
    NotifierProvider<ChatLocalPrefsController, ChatLocalPrefs>(
      ChatLocalPrefsController.new,
    );
