import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/message_cache_store.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

void main() {
  MessageEntity message(
    String chatId,
    int seq, {
    String? content,
    DateTime? createdAt,
  }) => MessageEntity(
    id: '$chatId-$seq',
    chatId: chatId,
    seq: seq,
    authorId: 9,
    type: MessageType.text,
    content: content ?? 'message $seq',
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: createdAt ?? DateTime.utc(2026, 3, 10).add(Duration(minutes: seq)),
  );

  test('remembers what it was given, per chat', () {
    final store = InMemoryMessageCacheStore();

    store.remember('a', [message('a', 1), message('a', 2)]);
    store.remember('b', [message('b', 1)]);

    expect(store.messagesOf('a'), hasLength(2));
    expect(store.messagesOf('b'), hasLength(1));
    expect(store.all(), hasLength(3));
  });

  test('ignores messages filed under the wrong chat', () {
    final store = InMemoryMessageCacheStore();

    store.remember('a', [message('b', 1)]);

    expect(store.messagesOf('a'), isEmpty);
  });

  test('a message seen twice is stored once, with the newer copy', () {
    final store = InMemoryMessageCacheStore();

    store.remember('a', [message('a', 1, content: 'first')]);
    store.remember('a', [message('a', 1, content: 'edited')]);

    expect(store.messagesOf('a').single.content, 'edited');
  });

  test('keeps the newest messages when a chat overflows', () {
    final store = InMemoryMessageCacheStore(perChatLimit: 3);

    store.remember('a', [
      for (var seq = 1; seq <= 10; seq++) message('a', seq),
    ]);

    final seqs = store.messagesOf('a').map((m) => m.seq).toList()..sort();
    expect(seqs, [8, 9, 10]);
  });

  test('forgets the chat nobody has touched in longest', () {
    final store = InMemoryMessageCacheStore(chatLimit: 2);

    store.remember('a', [message('a', 1)]);
    store.remember('b', [message('b', 1)]);
    store.remember('a', [message('a', 2)]);
    store.remember('c', [message('c', 1)]);

    expect(store.messagesOf('b'), isEmpty);
    expect(store.messagesOf('a'), isNotEmpty);
    expect(store.messagesOf('c'), isNotEmpty);
  });

  test('forget drops a chat outright', () {
    final store = InMemoryMessageCacheStore();

    store.remember('a', [message('a', 1)]);
    store.forget('a');

    expect(store.messagesOf('a'), isEmpty);
    expect(store.length, 0);
  });

  group('reconciling a window', () {
    test('drops a message deleted inside the window it covers', () {
      final store = InMemoryMessageCacheStore();
      store.remember('a', [message('a', 1), message('a', 2), message('a', 3)]);

      store.remember('a', [
        message('a', 1),
        message('a', 3),
      ], reconcile: true);

      expect(store.messagesOf('a').map((m) => m.seq), unorderedEquals([1, 3]));
    });

    test('leaves older messages outside the window alone', () {
      final store = InMemoryMessageCacheStore();
      store.remember('a', [message('a', 1), message('a', 2), message('a', 9)]);

      // A window over the newest messages says nothing about seq 1 and 2.
      store.remember('a', [message('a', 9)], reconcile: true);

      expect(
        store.messagesOf('a').map((m) => m.seq),
        unorderedEquals([1, 2, 9]),
      );
    });

    test('without reconciling, nothing is ever dropped', () {
      final store = InMemoryMessageCacheStore();
      store.remember('a', [message('a', 1), message('a', 2)]);

      store.remember('a', [message('a', 1)]);

      expect(store.messagesOf('a'), hasLength(2));
    });
  });
}
