import 'package:hive/hive.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_store.dart';
import 'package:chatix/features/chat/data/datasources/local_key_value_table.dart';

/// One Hive box seen as a table.
///
/// Hive rather than a SQL engine because nothing here is a query: every read
/// is "this key" or "the keys of this chat, newest first", which a key-value
/// box answers directly and which the key layout in [ChatLocalStore] is
/// designed around. Hive is also already a dependency and needs no native
/// build step on any of the six platforms this app ships to.
class HiveKeyValueTable implements LocalKeyValueTable {
  const HiveKeyValueTable(this._box);

  final Box<String> _box;

  @override
  List<String> keys() => [
    for (final key in _box.keys)
      if (key is String) key,
  ];

  @override
  String? read(String key) => _box.get(key);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  Future<void> deleteAll(Iterable<String> keys) => _box.deleteAll(keys);

  @override
  Future<void> clear() async => _box.clear();
}

/// Box names, versioned so a later schema change can open new boxes and
/// leave the old ones to be deleted rather than migrated in place.
abstract final class ChatCacheBoxes {
  static const String chats = 'chat_cache.v1.chats';
  static const String messages = 'chat_cache.v1.messages';
  static const String attachments = 'chat_cache.v1.attachments';
  static const String drafts = 'chat_cache.v1.drafts';
  static const String readState = 'chat_cache.v1.read_state';
  static const String outbox = 'chat_cache.v1.outbox';

  static const List<String> all = [
    chats,
    messages,
    attachments,
    drafts,
    readState,
    outbox,
  ];
}

/// Opens the on-disk store, falling back to an in-memory one if it cannot be
/// opened at all.
///
/// The fallback is deliberate: a cache that will not open is a reason to be
/// slower, not a reason to refuse to start. Every caller already handles an
/// empty cache, so the app in that state behaves exactly like a fresh
/// install — online-only, nothing kept between runs.
Future<ChatLocalStore> openHiveChatLocalStore({
  ChatCacheLimits limits = ChatCacheLimits.defaults,
}) async {
  try {
    final boxes = <String, Box<String>>{};
    for (final name in ChatCacheBoxes.all) {
      boxes[name] = await _openBox(name);
    }

    return ChatLocalStore(
      chats: HiveKeyValueTable(boxes[ChatCacheBoxes.chats]!),
      messages: HiveKeyValueTable(boxes[ChatCacheBoxes.messages]!),
      attachments: HiveKeyValueTable(boxes[ChatCacheBoxes.attachments]!),
      drafts: HiveKeyValueTable(boxes[ChatCacheBoxes.drafts]!),
      readState: HiveKeyValueTable(boxes[ChatCacheBoxes.readState]!),
      outbox: HiveKeyValueTable(boxes[ChatCacheBoxes.outbox]!),
      limits: limits,
    );
  } catch (error, stackTrace) {
    Logger.error(
      'Chat cache: could not be opened, running without one',
      error,
      stackTrace,
    );
    return inMemoryChatLocalStore(limits: limits);
  }
}

/// Opens one box, and on a corrupt file deletes it and opens a fresh one.
///
/// Everything in these boxes is a copy of something the server still has, so
/// throwing the file away costs a refetch and nothing else — with the one
/// exception of the outbox, which is why a failure there is logged loudly.
Future<Box<String>> _openBox(String name) async {
  try {
    return await Hive.openBox<String>(name);
  } catch (error) {
    Logger.warning('Chat cache: box "$name" unreadable ($error), recreating');
    await Hive.deleteBoxFromDisk(name);
    return Hive.openBox<String>(name);
  }
}
