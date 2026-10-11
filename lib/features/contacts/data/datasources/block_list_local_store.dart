import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';

/// This device's copy of whom the owner has blocked.
///
/// Ids only — the screen reads names and faces from the server, page by
/// page — so that what has to be known before anything else has loaded
/// (whether a chat gets a composer, whether a badge counts a chat) is known
/// on the first frame.
abstract interface class BlockListLocalStore {
  /// Synchronous: read while the first frame is being built.
  BlockList? read();

  Future<void> save(BlockList list);

  Future<void> clear();
}

/// The store over `SharedPreferences`, the same file the notification
/// settings live in.
class PrefsBlockListLocalStore implements BlockListLocalStore {
  PrefsBlockListLocalStore(this._prefs);

  static const String storageKey = 'contacts.blocked.v1';

  final SharedPreferences _prefs;

  BlockList? _mirror;
  bool _loaded = false;

  @override
  BlockList? read() {
    if (!_loaded) {
      _mirror = decode(_prefs.getString(storageKey));
      _loaded = true;
    }
    return _mirror;
  }

  @override
  Future<void> save(BlockList list) async {
    _mirror = list;
    _loaded = true;
    await _prefs.setString(storageKey, encode(list));
  }

  @override
  Future<void> clear() async {
    _mirror = null;
    _loaded = true;
    await _prefs.remove(storageKey);
  }

  static String encode(BlockList list) => json.encode({
    'owner_id': list.ownerId,
    'user_ids': (list.userIds.toList()..sort()),
  });

  /// Null for nothing stored and for anything unreadable: the next sync
  /// reads the list again, which is all a broken copy would cost.
  static BlockList? decode(String? raw) {
    if (raw == null) return null;
    try {
      final map = (json.decode(raw) as Map).cast<String, dynamic>();
      return BlockList(
        ownerId: map['owner_id'] as int,
        userIds: {
          for (final id in map['user_ids'] as List)
            if (id is int) id,
        },
      );
    } catch (error) {
      Logger.warning('Block list cache: unreadable, starting over ($error)');
      return null;
    }
  }
}

/// The store where there is no disk: tests, and any setup that never handed
/// over `SharedPreferences`.
class MemoryBlockListLocalStore implements BlockListLocalStore {
  MemoryBlockListLocalStore([this._list]);

  BlockList? _list;

  @override
  BlockList? read() => _list;

  @override
  Future<void> save(BlockList list) async => _list = list;

  @override
  Future<void> clear() async => _list = null;
}

/// Memory by default, the preferences file once `main()` overrides it — the
/// way the contact book's store is wired.
final blockListLocalStoreProvider = Provider<BlockListLocalStore>(
  (ref) => MemoryBlockListLocalStore(),
);
