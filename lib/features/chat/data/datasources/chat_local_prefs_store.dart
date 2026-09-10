import 'dart:convert';

import 'package:chatix/core/storage/local_storage_service.dart';

/// A per-chat flag the backend does not know about.
///
/// Pinning, archiving and silencing notifications are all client-side ideas:
/// `/chats/` has no field for any of them, and `MemberChatDTO.is_muted` is a
/// moderator mute (api-docs §8.1, right `member:mute`) that stops the member
/// writing — nothing to do with whether this device rings.
enum ChatLocalFlag {
  pinned('chat_flags.pinned'),
  archived('chat_flags.archived'),
  muted('chat_flags.muted');

  const ChatLocalFlag(this.storageKey);

  final String storageKey;
}

/// Where the device-local chat flags and drafts are kept.
abstract interface class ChatLocalPrefsStore {
  Set<String> readFlag(ChatLocalFlag flag);

  Future<void> writeFlag(ChatLocalFlag flag, Set<String> chatIds);

  Map<String, String> readDrafts();

  Future<void> writeDrafts(Map<String, String> drafts);
}

/// The real store: shared preferences, one list per flag and one JSON blob
/// for the drafts.
class SharedPrefsChatLocalPrefsStore implements ChatLocalPrefsStore {
  SharedPrefsChatLocalPrefsStore(this._storage);

  static const String _draftsKey = 'chat_drafts';

  final LocalStorageService _storage;

  @override
  Set<String> readFlag(ChatLocalFlag flag) {
    final stored = _storage.getStringList(flag.storageKey);
    if (stored == null || stored.isEmpty) return const <String>{};
    return stored.toSet();
  }

  @override
  Future<void> writeFlag(ChatLocalFlag flag, Set<String> chatIds) async {
    if (chatIds.isEmpty) {
      await _storage.remove(flag.storageKey);
      return;
    }
    await _storage.setStringList(flag.storageKey, chatIds.toList());
  }

  @override
  Map<String, String> readDrafts() {
    final raw = _storage.getString(_draftsKey);
    if (raw == null || raw.isEmpty) return const <String, String>{};

    final decoded = json.decode(raw);
    if (decoded is! Map) return const <String, String>{};

    return {
      for (final entry in decoded.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
  }

  @override
  Future<void> writeDrafts(Map<String, String> drafts) async {
    if (drafts.isEmpty) {
      await _storage.remove(_draftsKey);
      return;
    }
    await _storage.setString(_draftsKey, json.encode(drafts));
  }
}

/// The fallback used where shared preferences were never wired up — widget
/// tests, mostly. Flags and drafts still work for the life of the process,
/// they just do not outlive it.
class InMemoryChatLocalPrefsStore implements ChatLocalPrefsStore {
  final Map<ChatLocalFlag, Set<String>> _flags = <ChatLocalFlag, Set<String>>{};
  Map<String, String> _drafts = const <String, String>{};

  @override
  Set<String> readFlag(ChatLocalFlag flag) =>
      _flags[flag] ?? const <String>{};

  @override
  Future<void> writeFlag(ChatLocalFlag flag, Set<String> chatIds) async {
    _flags[flag] = {...chatIds};
  }

  @override
  Map<String, String> readDrafts() => _drafts;

  @override
  Future<void> writeDrafts(Map<String, String> drafts) async {
    _drafts = {...drafts};
  }
}
