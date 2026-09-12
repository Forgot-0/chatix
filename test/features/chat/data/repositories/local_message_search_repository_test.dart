import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/message_cache_store.dart';
import 'package:chatix/features/chat/data/repositories/local_message_search_repository.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';

void main() {
  late InMemoryMessageCacheStore store;
  late LocalMessageSearchRepository repository;

  setUp(() {
    store = InMemoryMessageCacheStore();
    repository = LocalMessageSearchRepository(store);
  });

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
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: createdAt ?? DateTime.utc(2026, 3, 10, seq),
  );

  Future<MessageSearchResult> search(String query, {String? chatId}) async {
    final result = await repository.search(query, chatId: chatId);
    return result.getOrElse((failure) => fail('unexpected ${failure.message}'));
  }

  test('says out loud that it only searched this device', () async {
    expect(repository.source, MessageSearchSource.localCache);

    final result = await search('anything');
    expect(result.source, MessageSearchSource.localCache);
  });

  test('finds a message by its content, ignoring case', () async {
    store.remember('a', [message('a', 1, content: 'Ship it tomorrow')]);

    final result = await search('SHIP');

    expect(result.hits, hasLength(1));
    expect(result.hits.single.message.seq, 1);
  });

  test('the hit carries the piece of the message that matched', () async {
    store.remember('a', [
      message('a', 1, content: '${'x' * 300} needle ${'y' * 300}'),
    ]);

    final hit = (await search('needle')).hits.single;

    expect(hit.snippet.length, lessThan(200));
    expect(
      hit.snippet.substring(hit.matchStart, hit.matchStart + hit.matchLength),
      'needle',
    );
  });

  test('newest first', () async {
    store.remember('a', [
      message('a', 1, content: 'ship one', createdAt: DateTime.utc(2026, 1, 1)),
      message('a', 2, content: 'ship two', createdAt: DateTime.utc(2026, 2, 1)),
      message(
        'a',
        3,
        content: 'ship three',
        createdAt: DateTime.utc(2026, 3, 1),
      ),
    ]);

    final result = await search('ship');

    expect(result.hits.map((h) => h.seq), [3, 2, 1]);
  });

  test('searches every chat, or only the one it was asked about', () async {
    store.remember('a', [message('a', 1, content: 'ship it')]);
    store.remember('b', [message('b', 1, content: 'ship that')]);

    expect((await search('ship')).hits, hasLength(2));
    expect((await search('ship', chatId: 'b')).hits.single.chatId, 'b');
  });

  test('a message with no text cannot match', () async {
    store.remember('a', [message('a', 1)]);

    expect((await search('anything')).hits, isEmpty);
  });

  test('an empty query is an empty result, not an error', () async {
    store.remember('a', [message('a', 1, content: 'ship it')]);

    final result = await search('   ');

    expect(result.isEmpty, isTrue);
  });

  test('says when there were more matches than it returned', () async {
    store.remember('a', [
      for (var seq = 1; seq <= 10; seq++)
        message('a', seq, content: 'ship $seq'),
    ]);

    final result = await repository.search('ship', limit: 4);

    result.match((failure) => fail('unexpected ${failure.message}'), (found) {
      expect(found.hits, hasLength(4));
      expect(found.isCapped, isTrue);
    });
  });

  test('a full result is not marked as capped', () async {
    store.remember('a', [message('a', 1, content: 'ship it')]);

    expect((await search('ship')).isCapped, isFalse);
  });
}
