import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/models/chat_model.dart';
import 'package:chatix/features/chat/data/models/message_model.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/outbox_entry.dart';
import 'package:chatix/features/chat/domain/repositories/chat_local_repository.dart';

/// Reads and writes the device's own copy, and nothing else.
///
/// Rows are stored as the API's own JSON, so a message written from a REST
/// page, a `ws.history` replay or a `new_message` push is the same row
/// whichever way it arrived, and reading it back cannot drift from what the
/// network layer would have produced. A row this build cannot parse is
/// dropped rather than thrown — it is a copy of something the server still
/// has, and the cost of losing one is a refetch.
class ChatLocalRepositoryImpl implements ChatLocalRepository {
  ChatLocalRepositoryImpl(this._local);

  final ChatLocalDataSource _local;

  /// How many messages of one chat are handed back by default.
  ///
  /// A little more than the 30 a screen opens with (api-docs §5.4), so the
  /// first paint is a full screen with room to scroll rather than exactly
  /// one screenful.
  static const int window = 60;

  @override
  ChatsPage? localChats({bool archived = false}) {
    final cached = _local.readChatList(archived: archived);
    if (cached == null) return null;

    final chats = <ChatEntity>[];
    for (final row in cached.chats) {
      final chat = _decodeChat(row);
      if (chat != null) chats.add(chat);
    }

    return ChatsPage(
      chats: chats,
      hasNext: cached.hasNext,
      nextDate: cached.nextDate,
      nextChatId: cached.nextChatId,
    );
  }

  @override
  List<MessageEntity> localMessages(String chatId, {int limit = window}) {
    final messages = <MessageEntity>[];
    for (final row in _local.readMessages(chatId, limit: limit)) {
      final message = _decodeMessage(row);
      if (message != null) messages.add(message);
    }
    return messages;
  }

  @override
  Future<void> rememberMessages(
    String chatId,
    List<MessageEntity> messages,
  ) async {
    if (messages.isEmpty) return;

    await _local.writeMessages(chatId, [
      for (final message in messages) message.toModel().toJson(),
    ]);

    var highest = messages.first.seq;
    for (final message in messages) {
      if (message.seq > highest) highest = message.seq;
    }
    await rememberSeq(chatId, lastSeq: highest);
  }

  @override
  Future<void> forgetChat(String chatId) => _local.forgetChat(chatId);

  @override
  Future<void> forgetMessage(String chatId, String messageId) =>
      _local.deleteMessage(chatId, messageId);

  @override
  Map<String, int> localResumeCursors() {
    return {
      for (final entry in _local.readReadStates().entries)
        if (entry.value.lastSeq > 0) entry.key: entry.value.lastSeq,
    };
  }

  @override
  int? localReportedReadSeq(String chatId) {
    final state = _local.readReadState(chatId);
    if (state == null || state.reportedSeq <= 0) return null;
    return state.reportedSeq;
  }

  @override
  Future<void> rememberSeq(
    String chatId, {
    int? lastSeq,
    int? reportedSeq,
  }) async {
    if (chatId.isEmpty) return;

    final known =
        _local.readReadState(chatId) ??
        ChatReadState(
          chatId: chatId,
          lastSeq: 0,
          reportedSeq: 0,
          updatedAt: DateTime.now(),
        );

    // Both cursors only ever move forward. A refetch of an older window, or
    // a read report racing a later one, must not walk them back: a cursor
    // that went backwards would replay history the reader has already seen.
    final nextLast = lastSeq != null && lastSeq > known.lastSeq
        ? lastSeq
        : known.lastSeq;
    final nextReported = reportedSeq != null && reportedSeq > known.reportedSeq
        ? reportedSeq
        : known.reportedSeq;

    if (nextLast == known.lastSeq && nextReported == known.reportedSeq) return;

    await _local.writeReadState(
      known.copyWith(
        lastSeq: nextLast,
        reportedSeq: nextReported,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  List<OutboxEntry> localOutbox() {
    final entries = <OutboxEntry>[];
    for (final row in _local.readOutbox()) {
      final entry = OutboxEntry.fromJson(row);
      if (entry != null) {
        entries.add(entry);
      } else {
        Logger.warning('Outbox: dropping a row this build cannot read');
      }
    }
    return entries;
  }

  @override
  Future<void> saveOutboxEntry(OutboxEntry entry) =>
      _local.writeOutboxEntry(Map<String, dynamic>.from(entry.toJson()));

  @override
  Future<void> dropOutboxEntry(String id) => _local.deleteOutboxEntry(id);

  @override
  Future<void> forgetEverything() => _local.clear();

  ChatEntity? _decodeChat(Map<String, dynamic> row) {
    try {
      return ChatModel.fromJson(row).toEntity();
    } catch (error) {
      Logger.warning('Chat cache: unreadable chat row ($error)');
      return null;
    }
  }

  MessageEntity? _decodeMessage(Map<String, dynamic> row) {
    try {
      return MessageModel.fromJson(row).toEntity();
    } catch (error) {
      Logger.warning('Chat cache: unreadable message row ($error)');
      return null;
    }
  }
}

/// Deliberately free of the network layer: a screen that only wants to know
/// what this device already holds must not drag an HTTP client into
/// existence to find out.
final chatLocalRepositoryProvider = Provider<ChatLocalRepository>((ref) {
  return ChatLocalRepositoryImpl(ref.watch(chatLocalDataSourceProvider));
});
