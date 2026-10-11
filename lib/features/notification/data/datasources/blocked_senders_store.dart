import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/features/notification/domain/entities/blocked_senders.dart';

/// Keeps [BlockedSenders] where the background isolate can find it.
///
/// A push that arrives while the app is closed is drawn by an isolate with
/// no provider graph (see `background_notification_handler.dart`); it reads
/// this from `SharedPreferences` the way it reads the notification settings.
/// The running app writes it whenever the block list or the direct chats
/// change.
abstract interface class BlockedSendersStore {
  BlockedSenders load();

  Future<void> save(BlockedSenders senders);
}

class PrefsBlockedSendersStore implements BlockedSendersStore {
  const PrefsBlockedSendersStore(this._prefs);

  static const String storageKey = 'notification_blocked_senders';

  final SharedPreferences _prefs;

  /// Anything unreadable is "nobody": a corrupt entry must not be the reason
  /// a notification from somebody else goes missing.
  @override
  BlockedSenders load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return BlockedSenders.none;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return BlockedSenders.none;
      return BlockedSenders.fromJson(Map<String, Object?>.from(decoded));
    } on Object {
      return BlockedSenders.none;
    }
  }

  @override
  Future<void> save(BlockedSenders senders) {
    if (senders.isEmpty) return _prefs.remove(storageKey);
    return _prefs.setString(storageKey, jsonEncode(senders.toJson()));
  }

  /// Reads it without an app around it, for the background isolate.
  static Future<BlockedSenders> loadStandalone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return PrefsBlockedSendersStore(prefs).load();
    } on Object {
      return BlockedSenders.none;
    }
  }
}

class MemoryBlockedSendersStore implements BlockedSendersStore {
  BlockedSenders _senders = BlockedSenders.none;

  @override
  BlockedSenders load() => _senders;

  @override
  Future<void> save(BlockedSenders senders) async => _senders = senders;
}

/// Memory by default — tests, and anything that never handed over
/// `SharedPreferences` — and the preferences file once `main()` overrides it.
final blockedSendersStoreProvider = Provider<BlockedSendersStore>(
  (ref) => MemoryBlockedSendersStore(),
);
