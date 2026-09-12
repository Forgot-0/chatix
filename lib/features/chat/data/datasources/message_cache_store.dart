import 'dart:collection';

import 'package:chatix/features/chat/domain/entities/message_entity.dart';

/// The messages this device has loaded, kept so they can be searched.
///
/// The API has no message search (api-docs §5.4), so the only history a
/// client can search is the history it already has. This is that history:
/// whatever the chat list previews carry, plus everything a chat screen has
/// pulled while it was open.
///
/// In memory on purpose. A persistent store that survives a restart belongs
/// with the offline work, and when it lands it implements this same
/// interface and the search above it does not change.
abstract interface class MessageCacheStore {
  /// Files [messages] under [chatId].
  ///
  /// With [reconcile], the incoming list is taken as the whole truth for the
  /// span of sequence numbers it covers: anything cached inside that span and
  /// missing from it was deleted, and is dropped. Callers handing over a
  /// partial view — a single preview, one new message — leave it off.
  void remember(
    String chatId,
    Iterable<MessageEntity> messages, {
    bool reconcile = false,
  });

  /// Forgets a chat: left, deleted, or otherwise no longer ours.
  void forget(String chatId);

  List<MessageEntity> messagesOf(String chatId);

  /// Everything cached, across every chat.
  List<MessageEntity> all();

  int get length;
}

/// Bounded in both directions: a cap per chat, and a cap on how many chats
/// are kept at all. Both are generous enough that browsing a conversation
/// makes it searchable, and small enough that a long session cannot grow
/// without limit.
class InMemoryMessageCacheStore implements MessageCacheStore {
  InMemoryMessageCacheStore({this.perChatLimit = 300, this.chatLimit = 40})
    : assert(perChatLimit > 0, 'a chat with no room is not a cache'),
      assert(chatLimit > 0, 'a cache with no room for chats is not a cache');

  final int perChatLimit;
  final int chatLimit;

  /// Chat id to its messages by id. Both maps are insertion-ordered, which is
  /// what makes eviction "the chat nobody has touched in longest".
  final LinkedHashMap<String, Map<String, MessageEntity>> _byChat =
      LinkedHashMap<String, Map<String, MessageEntity>>();

  @override
  void remember(
    String chatId,
    Iterable<MessageEntity> messages, {
    bool reconcile = false,
  }) {
    final incoming = messages.where((m) => m.chatId == chatId).toList();
    if (incoming.isEmpty) return;

    final chat = _touch(chatId);

    if (reconcile) {
      _dropDeleted(chat, incoming);
    }

    for (final message in incoming) {
      chat[message.id] = message;
    }

    _evictOldest(chat);
  }

  /// Removes what the caller's window says is gone.
  ///
  /// Only inside the span the window covers: a message older than anything
  /// loaded has not been deleted, it is simply not on screen.
  void _dropDeleted(
    Map<String, MessageEntity> chat,
    List<MessageEntity> window,
  ) {
    var lowest = window.first.seq;
    var highest = window.first.seq;
    for (final message in window) {
      if (message.seq < lowest) lowest = message.seq;
      if (message.seq > highest) highest = message.seq;
    }

    final kept = window.map((m) => m.id).toSet();

    chat.removeWhere(
      (id, cached) =>
          cached.seq >= lowest && cached.seq <= highest && !kept.contains(id),
    );
  }

  /// Keeps the newest [perChatLimit] messages of a chat.
  void _evictOldest(Map<String, MessageEntity> chat) {
    if (chat.length <= perChatLimit) return;

    final bySeq = chat.values.toList()..sort((a, b) => b.seq.compareTo(a.seq));

    for (final message in bySeq.skip(perChatLimit)) {
      chat.remove(message.id);
    }
  }

  /// Moves a chat to the back of the queue and makes room if this is a chat
  /// the cache has not seen before.
  Map<String, MessageEntity> _touch(String chatId) {
    final existing = _byChat.remove(chatId);
    final chat = existing ?? <String, MessageEntity>{};
    _byChat[chatId] = chat;

    while (_byChat.length > chatLimit) {
      _byChat.remove(_byChat.keys.first);
    }

    return chat;
  }

  @override
  void forget(String chatId) => _byChat.remove(chatId);

  @override
  List<MessageEntity> messagesOf(String chatId) =>
      _byChat[chatId]?.values.toList() ?? const <MessageEntity>[];

  @override
  List<MessageEntity> all() => [
    for (final chat in _byChat.values) ...chat.values,
  ];

  @override
  int get length =>
      _byChat.values.fold(0, (total, chat) => total + chat.length);
}
