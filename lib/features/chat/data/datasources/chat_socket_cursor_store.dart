import 'dart:async';

import 'package:chatix/core/websocket/socket_cursor_store.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';

/// The socket's resume cursors, kept in the chat store.
///
/// The adapter exists so `core/websocket` can stay ignorant of the chat
/// feature: it asks for `{chat_id: last_seq}` and is handed the `last_seq`
/// column of the read-state table, which the repository is already moving
/// forward every time a page of messages is written down.
class ChatCacheSocketCursorStore implements SocketCursorStore {
  ChatCacheSocketCursorStore(this._local);

  final ChatLocalDataSource _local;

  @override
  Map<String, int> load() {
    return {
      for (final entry in _local.readReadStates().entries)
        if (entry.value.lastSeq > 0) entry.key: entry.value.lastSeq,
    };
  }

  @override
  void save(String chatId, int seq) {
    final known = _local.readReadState(chatId);
    if (known != null && known.lastSeq >= seq) return;

    // The socket is on the frame-handling path and cannot wait for a disk
    // write; a cursor that loses the last few frames of a run costs a short
    // replay at the next start, which is what `ws.history` is for anyway.
    unawaited(
      _local.writeReadState(
        (known ??
                ChatReadState(
                  chatId: chatId,
                  lastSeq: 0,
                  reportedSeq: 0,
                  updatedAt: DateTime.now(),
                ))
            .copyWith(lastSeq: seq, updatedAt: DateTime.now()),
      ),
    );
  }
}
