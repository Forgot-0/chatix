import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/data/datasources/chat_local_store.dart';

/// The device's own copy of the chat data, and the queue of writes that have
/// not reached the server yet.
///
/// Everything a chat screen needs to draw itself before a single request has
/// been answered lives behind this interface: the chat list as it last
/// looked, the newest slice of every chat that has been opened, the read
/// cursors that `resume` needs after a reconnect (api-docs §6.3), the drafts,
/// and the outbox.
///
/// Rows are stored as the API's own JSON rather than as some parallel local
/// schema. `MessageDTO` and `ChatDTO` already have exact codecs in
/// `data/models`, so a row written from a REST page, from a `ws.history`
/// replay or from a `new_message` push is byte-identical whichever way it
/// arrived, and reading it back cannot drift from what the network layer
/// would have produced.
///
/// Reads are synchronous. The store is opened once at startup, before the
/// first frame, so a screen can be built from the cache without a hop
/// through the event loop — which is the entire point of having it. Writes
/// are not: they go to disk.
abstract interface class ChatLocalDataSource {
  /// The chat list as it was last seen, or null if this device has never
  /// loaded one. [archived] picks between the two independent lists
  /// (api-docs §5.2).
  CachedChatList? readChatList({bool archived = false});

  Future<void> writeChatList(CachedChatList page, {bool archived = false});

  /// The newest cached messages of [chatId], newest first.
  List<Map<String, dynamic>> readMessages(String chatId, {int limit = 60});

  /// Files [messages] (raw `MessageDTO` JSON) under [chatId] and marks the
  /// chat as the most recently used one.
  Future<void> writeMessages(
    String chatId,
    List<Map<String, dynamic>> messages,
  );

  Future<void> deleteMessage(String chatId, String messageId);

  /// Drops everything held for a chat: left, deleted, or evicted.
  Future<void> forgetChat(String chatId);

  /// Chats with cached messages, most recently used first.
  List<String> cachedChatIds();

  CachedAttachment? readAttachment(String s3Key);

  List<CachedAttachment> readAttachments();

  Future<void> writeAttachment(CachedAttachment attachment);

  Future<void> deleteAttachments(Iterable<String> s3Keys);

  Map<String, String> readDrafts();

  Future<void> writeDrafts(Map<String, String> drafts);

  /// Every chat's read state, keyed by chat id.
  Map<String, ChatReadState> readReadStates();

  ChatReadState? readReadState(String chatId);

  Future<void> writeReadState(ChatReadState state);

  /// The queue, oldest first — which is the order it has to be drained in.
  List<Map<String, dynamic>> readOutbox();

  Future<void> writeOutboxEntry(Map<String, dynamic> entry);

  Future<void> deleteOutboxEntry(String id);

  /// Everything, for signing out.
  Future<void> clear();
}

/// One cached page of `GET /chats/` — the rows plus the cursor that would
/// fetch the next page (api-docs §5.2).
class CachedChatList extends Equatable {
  const CachedChatList({
    required this.chats,
    required this.hasNext,
    required this.nextDate,
    required this.nextChatId,
    required this.savedAt,
  });

  /// Raw `ChatDTO` JSON, in the order the server sent it.
  final List<Map<String, dynamic>> chats;

  final bool hasNext;

  /// The two halves of the chat-list cursor (api-docs §1.6).
  final String? nextDate;
  final String? nextChatId;

  final DateTime savedAt;

  Map<String, Object?> toJson() => {
    'chats': chats,
    'has_next': hasNext,
    'next_date': nextDate,
    'next_chat_id': nextChatId,
    'saved_at': savedAt.toIso8601String(),
  };

  static CachedChatList? fromJson(Map<String, dynamic> json) {
    final rows = json['chats'];
    if (rows is! List) return null;

    return CachedChatList(
      chats: [
        for (final row in rows)
          if (row is Map) Map<String, dynamic>.from(row),
      ],
      hasNext: json['has_next'] as bool? ?? false,
      nextDate: json['next_date'] as String?,
      nextChatId: json['next_chat_id'] as String?,
      savedAt:
          DateTime.tryParse(json['saved_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  List<Object?> get props => [chats, hasNext, nextDate, nextChatId, savedAt];
}

/// What is known about one downloaded attachment, keyed the only way an
/// attachment can be keyed.
///
/// `AttachmentDTO.url` expires after 300 seconds (api-docs §5.5), so it is
/// deliberately not here: the row is about the object, and `s3_key` names the
/// object for as long as it exists. This is the index the media cache is
/// trimmed by, and the reason the settings screen can say how much room chat
/// media is taking before deleting any of it.
class CachedAttachment extends Equatable {
  const CachedAttachment({
    required this.s3Key,
    required this.chatId,
    required this.messageId,
    required this.mimeType,
    required this.originalFilename,
    required this.size,
    required this.cachedAt,
  });

  final String s3Key;
  final String chatId;
  final String? messageId;
  final String mimeType;
  final String originalFilename;
  final int size;
  final DateTime cachedAt;

  Map<String, Object?> toJson() => {
    's3_key': s3Key,
    'chat_id': chatId,
    'message_id': messageId,
    'mime_type': mimeType,
    'original_filename': originalFilename,
    'size': size,
    'cached_at': cachedAt.toIso8601String(),
  };

  static CachedAttachment? fromJson(Map<String, dynamic> json) {
    final s3Key = json['s3_key'];
    if (s3Key is! String || s3Key.isEmpty) return null;

    return CachedAttachment(
      s3Key: s3Key,
      chatId: json['chat_id'] as String? ?? '',
      messageId: json['message_id'] as String?,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      originalFilename: json['original_filename'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      cachedAt:
          DateTime.tryParse(json['cached_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  List<Object?> get props => [
    s3Key,
    chatId,
    messageId,
    mimeType,
    originalFilename,
    size,
    cachedAt,
  ];
}

/// Where a chat stands, from this device's point of view.
///
/// [lastSeq] is the resume cursor: the highest seq this device holds, which
/// is what `subscribe`/`resume` is given so the gateway can replay what was
/// missed (api-docs §6.3). [reportedSeq] is the other direction — how far
/// `POST /messages/read/` has been told the reader got, kept so a restart
/// does not re-report what was already reported.
class ChatReadState extends Equatable {
  const ChatReadState({
    required this.chatId,
    required this.lastSeq,
    required this.reportedSeq,
    required this.updatedAt,
  });

  final String chatId;
  final int lastSeq;
  final int reportedSeq;
  final DateTime updatedAt;

  ChatReadState copyWith({int? lastSeq, int? reportedSeq, DateTime? updatedAt}) {
    return ChatReadState(
      chatId: chatId,
      lastSeq: lastSeq ?? this.lastSeq,
      reportedSeq: reportedSeq ?? this.reportedSeq,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'chat_id': chatId,
    'last_seq': lastSeq,
    'reported_seq': reportedSeq,
    'updated_at': updatedAt.toIso8601String(),
  };

  static ChatReadState? fromJson(Map<String, dynamic> json) {
    final chatId = json['chat_id'];
    if (chatId is! String || chatId.isEmpty) return null;

    return ChatReadState(
      chatId: chatId,
      lastSeq: (json['last_seq'] as num?)?.toInt() ?? 0,
      reportedSeq: (json['reported_seq'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  List<Object?> get props => [chatId, lastSeq, reportedSeq, updatedAt];
}

/// How much the cache is allowed to hold.
///
/// Both numbers are bounds on a working set, not a download quota: the point
/// is that opening the app is instant and that a year of use does not turn
/// into a gigabyte of messages nobody will scroll back to. Whatever falls
/// out is still one request away.
class ChatCacheLimits {
  const ChatCacheLimits({this.chats = 30, this.messagesPerChat = 200});

  /// How many chats keep a message cache. Least recently opened goes first.
  final int chats;

  /// How many messages are kept per chat, newest first.
  final int messagesPerChat;

  static const ChatCacheLimits defaults = ChatCacheLimits();
}

/// The store this build talks to.
///
/// Defaults to one with nothing behind it and is overridden in `main()` with
/// the real one, opened before the first frame — the same shape as
/// `sharedPreferencesProvider`. A test that does not care about persistence
/// gets the in-memory store for free and behaves like a fresh install.
final chatLocalDataSourceProvider = Provider<ChatLocalDataSource>((ref) {
  return inMemoryChatLocalStore();
});
