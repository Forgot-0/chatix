import 'dart:convert';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/local_key_value_table.dart';

/// The local store, written once against [LocalKeyValueTable] so the rules
/// below are the same on disk and in memory.
///
/// Message keys are `chat_id + seq`, in that order and zero-padded, which is
/// what makes "the newest N messages of this chat" a sorted key range rather
/// than a scan-and-filter, and what makes a message impossible to store
/// twice: `seq` is unique within a chat (api-docs §5.4), so the same message
/// arriving from the cache, from REST and from the socket lands on one key.
class ChatLocalStore implements ChatLocalDataSource {
  ChatLocalStore({
    required LocalKeyValueTable chats,
    required LocalKeyValueTable messages,
    required LocalKeyValueTable attachments,
    required LocalKeyValueTable drafts,
    required LocalKeyValueTable readState,
    required LocalKeyValueTable outbox,
    this.limits = ChatCacheLimits.defaults,
    DateTime Function()? clock,
  }) : _chats = chats,
       _messages = messages,
       _attachments = attachments,
       _drafts = drafts,
       _readState = readState,
       _outbox = outbox,
       _now = clock ?? DateTime.now;

  /// Holds the two list snapshots and, under [_usagePrefix], when each chat
  /// was last opened — the order the LRU evicts in.
  final LocalKeyValueTable _chats;
  final LocalKeyValueTable _messages;
  final LocalKeyValueTable _attachments;
  final LocalKeyValueTable _drafts;
  final LocalKeyValueTable _readState;
  final LocalKeyValueTable _outbox;

  final ChatCacheLimits limits;
  final DateTime Function() _now;

  static const String _usagePrefix = 'usage:';
  static const String _mainListKey = 'list:main';
  static const String _archivedListKey = 'list:archived';

  /// Wide enough for any `seq` the server can reach, so the padded key sorts
  /// the same way the number does.
  static const int _seqWidth = 12;

  static String messageKey(String chatId, int seq) =>
      '$chatId#${seq.toString().padLeft(_seqWidth, '0')}';

  @override
  CachedChatList? readChatList({bool archived = false}) {
    final raw = _chats.read(archived ? _archivedListKey : _mainListKey);
    final decoded = _decode(raw);
    return decoded == null ? null : CachedChatList.fromJson(decoded);
  }

  @override
  Future<void> writeChatList(
    CachedChatList page, {
    bool archived = false,
  }) async {
    await _chats.write(
      archived ? _archivedListKey : _mainListKey,
      jsonEncode(page.toJson()),
    );
  }

  @override
  List<Map<String, dynamic>> readMessages(String chatId, {int limit = 60}) {
    if (limit <= 0) return const [];

    final keys = _keysOf(chatId)..sort((a, b) => b.compareTo(a));

    final messages = <Map<String, dynamic>>[];
    for (final key in keys) {
      if (messages.length >= limit) break;
      final decoded = _decode(_messages.read(key));
      if (decoded != null) messages.add(decoded);
    }
    return messages;
  }

  @override
  Future<void> writeMessages(
    String chatId,
    List<Map<String, dynamic>> messages,
  ) async {
    if (chatId.isEmpty) return;

    for (final message in messages) {
      final seq = (message['seq'] as num?)?.toInt();
      if (seq == null) continue;
      await _messages.write(messageKey(chatId, seq), jsonEncode(message));
    }

    await _touch(chatId);
    await _trim(chatId);
    await _evictChats();
  }

  @override
  Future<void> deleteMessage(String chatId, String messageId) async {
    for (final key in _keysOf(chatId)) {
      final decoded = _decode(_messages.read(key));
      if (decoded != null && decoded['id'] == messageId) {
        await _messages.delete(key);
        return;
      }
    }
  }

  @override
  Future<void> forgetChat(String chatId) async {
    await _messages.deleteAll(_keysOf(chatId));
    await _chats.delete('$_usagePrefix$chatId');
    await _readState.delete(chatId);

    // The index of what this chat's media weighs goes with it. The files
    // themselves are the file cache's to evict, by size and least recently
    // read — an object under an `s3_key` never changes, so an old copy is
    // never a stale one and there is nothing here that has to be deleted in
    // step with anything else.
    await _attachments.deleteAll([
      for (final attachment in readAttachments())
        if (attachment.chatId == chatId) attachment.s3Key,
    ]);
  }

  @override
  List<String> cachedChatIds() {
    final touched = <String, DateTime>{};

    for (final key in _chats.keys()) {
      if (!key.startsWith(_usagePrefix)) continue;
      final at = DateTime.tryParse(_chats.read(key) ?? '');
      if (at == null) continue;
      touched[key.substring(_usagePrefix.length)] = at;
    }

    final ids = touched.keys.toList()
      ..sort((a, b) => touched[b]!.compareTo(touched[a]!));
    return ids;
  }

  @override
  CachedAttachment? readAttachment(String s3Key) {
    final decoded = _decode(_attachments.read(s3Key));
    return decoded == null ? null : CachedAttachment.fromJson(decoded);
  }

  @override
  List<CachedAttachment> readAttachments() {
    final all = <CachedAttachment>[];
    for (final key in _attachments.keys()) {
      final decoded = _decode(_attachments.read(key));
      final attachment = decoded == null
          ? null
          : CachedAttachment.fromJson(decoded);
      if (attachment != null) all.add(attachment);
    }
    return all;
  }

  @override
  Future<void> writeAttachment(CachedAttachment attachment) =>
      _attachments.write(attachment.s3Key, jsonEncode(attachment.toJson()));

  @override
  Future<void> deleteAttachments(Iterable<String> s3Keys) =>
      _attachments.deleteAll(s3Keys);

  @override
  Map<String, String> readDrafts() {
    final drafts = <String, String>{};
    for (final key in _drafts.keys()) {
      final text = _drafts.read(key);
      if (text != null && text.isNotEmpty) drafts[key] = text;
    }
    return drafts;
  }

  @override
  Future<void> writeDrafts(Map<String, String> drafts) async {
    final gone = [
      for (final key in _drafts.keys())
        if (!drafts.containsKey(key)) key,
    ];
    await _drafts.deleteAll(gone);

    for (final entry in drafts.entries) {
      if (_drafts.read(entry.key) == entry.value) continue;
      await _drafts.write(entry.key, entry.value);
    }
  }

  @override
  Map<String, ChatReadState> readReadStates() {
    final states = <String, ChatReadState>{};
    for (final key in _readState.keys()) {
      final state = readReadState(key);
      if (state != null) states[key] = state;
    }
    return states;
  }

  @override
  ChatReadState? readReadState(String chatId) {
    final decoded = _decode(_readState.read(chatId));
    return decoded == null ? null : ChatReadState.fromJson(decoded);
  }

  @override
  Future<void> writeReadState(ChatReadState state) =>
      _readState.write(state.chatId, jsonEncode(state.toJson()));

  @override
  List<Map<String, dynamic>> readOutbox() {
    final entries = <Map<String, dynamic>>[];
    for (final key in _outbox.keys()) {
      final decoded = _decode(_outbox.read(key));
      if (decoded != null) entries.add(decoded);
    }

    // Oldest first: the queue has to go out in the order it was filled, and
    // key order is not guaranteed to have survived the restart.
    entries.sort((a, b) {
      final left = a['created_at'] as String? ?? '';
      final right = b['created_at'] as String? ?? '';
      return left.compareTo(right);
    });
    return entries;
  }

  @override
  Future<void> writeOutboxEntry(Map<String, dynamic> entry) async {
    final id = entry['id'];
    if (id is! String || id.isEmpty) return;
    await _outbox.write(id, jsonEncode(entry));
  }

  @override
  Future<void> deleteOutboxEntry(String id) => _outbox.delete(id);

  @override
  Future<void> clear() async {
    await _chats.clear();
    await _messages.clear();
    await _attachments.clear();
    await _drafts.clear();
    await _readState.clear();
    await _outbox.clear();
  }

  List<String> _keysOf(String chatId) {
    final prefix = '$chatId#';
    return [
      for (final key in _messages.keys())
        if (key.startsWith(prefix)) key,
    ];
  }

  Future<void> _touch(String chatId) =>
      _chats.write('$_usagePrefix$chatId', _now().toIso8601String());

  /// Keeps the newest [ChatCacheLimits.messagesPerChat] of one chat.
  Future<void> _trim(String chatId) async {
    final keys = _keysOf(chatId);
    if (keys.length <= limits.messagesPerChat) return;

    keys.sort((a, b) => b.compareTo(a));
    await _messages.deleteAll(keys.skip(limits.messagesPerChat));
  }

  /// Drops the chats nobody has opened in longest.
  ///
  /// A chat is evicted whole — cached messages and read state together —
  /// because half a chat is worse than none: a window with no cursor behind
  /// it would be drawn from the cache and then silently fail to catch up.
  Future<void> _evictChats() async {
    final ids = cachedChatIds();
    if (ids.length <= limits.chats) return;

    for (final chatId in ids.skip(limits.chats)) {
      await forgetChat(chatId);
    }
  }

  Map<String, dynamic>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (error) {
      Logger.warning('Chat cache: unreadable row dropped ($error)');
      return null;
    }
  }
}

/// The store with nothing behind it.
///
/// What every test and every platform without a working database gets: the
/// cache is real for the life of the process and empty at the next start, so
/// every caller takes the "nothing cached yet, go to the network" path it
/// already has to handle.
ChatLocalStore inMemoryChatLocalStore({
  ChatCacheLimits limits = ChatCacheLimits.defaults,
  DateTime Function()? clock,
}) {
  return ChatLocalStore(
    chats: MemoryKeyValueTable(),
    messages: MemoryKeyValueTable(),
    attachments: MemoryKeyValueTable(),
    drafts: MemoryKeyValueTable(),
    readState: MemoryKeyValueTable(),
    outbox: MemoryKeyValueTable(),
    limits: limits,
    clock: clock,
  );
}
