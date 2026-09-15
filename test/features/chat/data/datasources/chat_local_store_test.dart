import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_store.dart';
import 'package:chatix/features/chat/data/datasources/hive_chat_local_store.dart';
import 'package:chatix/features/chat/data/datasources/local_key_value_table.dart';

/// The store itself: what it keeps, what it throws away first, and that a
/// row written in one run reads back identically in the next.
void main() {
  Map<String, dynamic> message(int seq, {String? id, String body = 'hello'}) => {
    'id': id ?? 'm$seq',
    'chat_id': 'c1',
    'seq': seq,
    'author_id': 42,
    'type': 'text',
    'content': body,
    'reply_to_id': null,
    'forwarded_from_chat_id': null,
    'forwarded_from_message_id': null,
    'forwarded_from_author_id': null,
    'is_edited': false,
    'created_at': '2026-01-01T00:00:00Z',
    'attachments': <Object?>[],
    'reactions': <Object?>[],
  };

  group('messages', () {
    test('come back newest first', () async {
      final store = inMemoryChatLocalStore();
      await store.writeMessages('c1', [message(2), message(9), message(5)]);

      expect(
        store.readMessages('c1').map((m) => m['seq']),
        [9, 5, 2],
      );
    });

    test('are keyed by chat and seq, so one seq is one row', () async {
      // The same message arriving from the cache, from REST and from the
      // socket has to land on one key — `seq` is unique within a chat
      // (api-docs §5.4).
      final store = inMemoryChatLocalStore();
      await store.writeMessages('c1', [message(4, body: 'first')]);
      await store.writeMessages('c1', [message(4, body: 'edited')]);

      final rows = store.readMessages('c1');
      expect(rows, hasLength(1));
      expect(rows.single['content'], 'edited');
    });

    test('of one chat never leak into another', () async {
      final store = inMemoryChatLocalStore();
      await store.writeMessages('c1', [message(1)]);
      await store.writeMessages('c2', [message(2)]);

      expect(store.readMessages('c1'), hasLength(1));
      expect(store.readMessages('c2'), hasLength(1));
    });

    test('are trimmed to the newest the chat may keep', () async {
      final store = inMemoryChatLocalStore(
        limits: const ChatCacheLimits(chats: 5, messagesPerChat: 3),
      );
      await store.writeMessages('c1', [
        for (var seq = 1; seq <= 10; seq++) message(seq),
      ]);

      expect(store.readMessages('c1').map((m) => m['seq']), [10, 9, 8]);
    });

    test('a deleted one is dropped by id', () async {
      final store = inMemoryChatLocalStore();
      await store.writeMessages('c1', [message(1), message(2)]);
      await store.deleteMessage('c1', 'm1');

      expect(store.readMessages('c1').map((m) => m['id']), ['m2']);
    });
  });

  group('the LRU over chats', () {
    test('evicts the chat nobody has opened in longest', () async {
      var tick = DateTime.utc(2026, 1, 1);
      final store = inMemoryChatLocalStore(
        limits: const ChatCacheLimits(chats: 2, messagesPerChat: 10),
        clock: () => tick = tick.add(const Duration(minutes: 1)),
      );

      await store.writeMessages('a', [message(1)]);
      await store.writeMessages('b', [message(1)]);
      await store.writeMessages('c', [message(1)]);

      expect(store.cachedChatIds(), ['c', 'b']);
      expect(store.readMessages('a'), isEmpty);
    });

    test('reopening a chat keeps it', () async {
      var tick = DateTime.utc(2026, 1, 1);
      final store = inMemoryChatLocalStore(
        limits: const ChatCacheLimits(chats: 2, messagesPerChat: 10),
        clock: () => tick = tick.add(const Duration(minutes: 1)),
      );

      await store.writeMessages('a', [message(1)]);
      await store.writeMessages('b', [message(1)]);
      await store.writeMessages('a', [message(2)]);
      await store.writeMessages('c', [message(1)]);

      // 'b' is the one nobody came back to.
      expect(store.readMessages('b'), isEmpty);
      expect(store.readMessages('a'), hasLength(2));
    });

    test('an evicted chat loses its cursor with its messages', () async {
      // Half a chat is worse than none: a window with no cursor behind it
      // would be drawn and then fail to catch up.
      var tick = DateTime.utc(2026, 1, 1);
      final store = inMemoryChatLocalStore(
        limits: const ChatCacheLimits(chats: 1, messagesPerChat: 10),
        clock: () => tick = tick.add(const Duration(minutes: 1)),
      );

      await store.writeMessages('a', [message(1)]);
      await store.writeReadState(
        ChatReadState(
          chatId: 'a',
          lastSeq: 1,
          reportedSeq: 1,
          updatedAt: DateTime.utc(2026),
        ),
      );
      await store.writeMessages('b', [message(1)]);

      expect(store.readReadState('a'), isNull);
    });
  });

  test('the chat list keeps both halves of its cursor', () async {
    // `GET /chats/` pages on last_activity_at + last_chat_id together
    // (api-docs §1.6); half a cursor fetches the wrong page.
    final store = inMemoryChatLocalStore();
    await store.writeChatList(
      CachedChatList(
        chats: [
          {'id': 'c1'},
        ],
        hasNext: true,
        nextDate: '2026-01-01T00:00:00Z',
        nextChatId: 'c1',
        savedAt: DateTime.utc(2026),
      ),
    );

    final cached = store.readChatList()!;
    expect(cached.nextDate, '2026-01-01T00:00:00Z');
    expect(cached.nextChatId, 'c1');
    expect(cached.hasNext, isTrue);
  });

  test('the archive is a separate list', () async {
    final store = inMemoryChatLocalStore();
    await store.writeChatList(
      CachedChatList(
        chats: [
          {'id': 'main'},
        ],
        hasNext: false,
        nextDate: null,
        nextChatId: null,
        savedAt: DateTime.utc(2026),
      ),
    );

    expect(store.readChatList(archived: true), isNull);
    expect(store.readChatList()!.chats.single['id'], 'main');
  });

  test('drafts are added, changed and removed as a set', () async {
    final store = inMemoryChatLocalStore();
    await store.writeDrafts({'a': 'one', 'b': 'two'});
    await store.writeDrafts({'a': 'edited'});

    expect(store.readDrafts(), {'a': 'edited'});
  });

  test('an unreadable row is dropped rather than thrown', () async {
    // Everything here is a copy of something the server still has, so a row
    // this build cannot parse costs a refetch and nothing else.
    final table = MemoryKeyValueTable();
    await table.write('c1#000000000001', 'not json');

    final store = ChatLocalStore(
      chats: MemoryKeyValueTable(),
      messages: table,
      attachments: MemoryKeyValueTable(),
      drafts: MemoryKeyValueTable(),
      readState: MemoryKeyValueTable(),
      outbox: MemoryKeyValueTable(),
    );

    expect(store.readMessages('c1'), isEmpty);
  });

  group('on disk', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('chatix_cache_test');
      Hive.init(directory.path);
    });

    tearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test('a message written in one run reads back in the next', () async {
      final first = await openHiveChatLocalStore();
      await first.writeMessages('c1', [message(7, body: 'survives')]);
      await Hive.close();

      final second = await openHiveChatLocalStore();
      final rows = second.readMessages('c1');

      expect(rows, hasLength(1));
      expect(rows.single['content'], 'survives');
      expect(rows.single['seq'], 7);
    });

    test('the outbox survives too, in the order it was filled', () async {
      final first = await openHiveChatLocalStore();
      await first.writeOutboxEntry({
        'id': 'e2',
        'chat_id': 'c1',
        'created_at': '2026-01-01T00:00:02Z',
      });
      await first.writeOutboxEntry({
        'id': 'e1',
        'chat_id': 'c1',
        'created_at': '2026-01-01T00:00:01Z',
      });
      await Hive.close();

      final second = await openHiveChatLocalStore();
      expect(second.readOutbox().map((e) => e['id']), ['e1', 'e2']);

      await second.deleteOutboxEntry('e1');
      expect(second.readOutbox().map((e) => e['id']), ['e2']);
    });
  });
}
