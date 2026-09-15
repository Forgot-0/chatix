import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/outbox_entry.dart';

/// What this device already knows, and what it still owes the server.
///
/// Separate from [ChatRepository] because it answers a different kind of
/// question. Nothing here reaches the network, nothing here can fail in a way
/// a screen should hear about — a chat that has never been opened simply has
/// nothing stored, which is a `null` rather than a `Failure` — and nothing
/// here needs an HTTP client to exist. Which store is behind it, or whether
/// there is one at all, stays the data layer's business.
///
/// [ChatRepository] writes through to the same store on its way out, so the
/// two never disagree: everything fetched is stored, and this is how it is
/// read back.
abstract class ChatLocalRepository {
  /// The chat list exactly as it was last fetched, or null if it never was.
  ChatsPage? localChats({bool archived = false});

  /// The newest messages held for [chatId], newest first, possibly empty.
  List<MessageEntity> localMessages(String chatId, {int limit = 60});

  /// Files messages that arrived somewhere other than through a repository
  /// call — over the socket, mostly.
  Future<void> rememberMessages(String chatId, List<MessageEntity> messages);

  /// Drops everything held for a chat that is no longer ours.
  Future<void> forgetChat(String chatId);

  /// Drops one stored message: deleted here, or deleted elsewhere and
  /// announced over the socket.
  Future<void> forgetMessage(String chatId, String messageId);

  /// The per-chat resume cursors: the highest `seq` this device holds, which
  /// is what `subscribe`/`resume` is handed after a reconnect (api-docs
  /// §6.3).
  Map<String, int> localResumeCursors();

  /// How far `POST /messages/read/` has already been told this reader got.
  int? localReportedReadSeq(String chatId);

  Future<void> rememberSeq(String chatId, {int? lastSeq, int? reportedSeq});

  /// The queue of writes that have not reached the server, oldest first.
  List<OutboxEntry> localOutbox();

  Future<void> saveOutboxEntry(OutboxEntry entry);

  Future<void> dropOutboxEntry(String id);

  /// Everything stored on this device, for signing out.
  Future<void> forgetEverything();
}
