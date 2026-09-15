import 'dart:convert';

import 'package:chatix/core/storage/local_storage_service.dart';

/// Where the device-local chat odds and ends are kept.
///
/// Pinning, archiving and silencing used to be among them. They are fields
/// on the chat row now — `is_pinned`, `is_archived`, `is_muted_by_me`
/// (api-docs §5.2) — written through `PATCH /chats/{chat_id}/state/`, and
/// they follow the account rather than the device. What is left here is what
/// the API still has nowhere to put.
abstract interface class ChatLocalPrefsStore {
  Map<String, String> readDrafts();

  Future<void> writeDrafts(Map<String, String> drafts);

  /// Emoji this device reacted with, most recent first.
  ///
  /// Device-local like everything else here: reactions themselves live on the
  /// server, but which ones this person reaches for first is a habit, not
  /// chat data, and there is no endpoint that stores it.
  List<String> readRecentReactions();

  Future<void> writeRecentReactions(List<String> emojis);
}

/// The real store: shared preferences, with one JSON blob for the drafts.
class SharedPrefsChatLocalPrefsStore implements ChatLocalPrefsStore {
  SharedPrefsChatLocalPrefsStore(this._storage);

  static const String _draftsKey = 'chat_drafts';
  static const String _recentReactionsKey = 'chat.recent_reactions';

  final LocalStorageService _storage;

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

  @override
  List<String> readRecentReactions() =>
      _storage.getStringList(_recentReactionsKey) ?? const <String>[];

  @override
  Future<void> writeRecentReactions(List<String> emojis) async {
    if (emojis.isEmpty) {
      await _storage.remove(_recentReactionsKey);
      return;
    }
    await _storage.setStringList(_recentReactionsKey, emojis);
  }
}

/// The fallback used where shared preferences were never wired up — widget
/// tests, mostly. Drafts still work for the life of the process, they just
/// do not outlive it.
class InMemoryChatLocalPrefsStore implements ChatLocalPrefsStore {
  Map<String, String> _drafts = const <String, String>{};
  List<String> _recentReactions = const <String>[];

  @override
  Map<String, String> readDrafts() => _drafts;

  @override
  Future<void> writeDrafts(Map<String, String> drafts) async {
    _drafts = {...drafts};
  }

  @override
  List<String> readRecentReactions() => [..._recentReactions];

  @override
  Future<void> writeRecentReactions(List<String> emojis) async {
    _recentReactions = [...emojis];
  }
}
