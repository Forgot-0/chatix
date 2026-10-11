import 'package:hive/hive.dart';

import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_store.dart';

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
      // Everything in these boxes is a copy of something the server still
      // has, so a corrupt file costs a refetch — with the one exception of
      // the outbox, which is why the recovery is logged loudly.
      boxes[name] = await openRecoverableHiveBox(name, label: 'Chat cache');
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
