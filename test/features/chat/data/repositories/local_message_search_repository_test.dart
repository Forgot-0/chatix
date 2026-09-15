import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/message_cache_store.dart';
import 'package:chatix/features/chat/data/repositories/local_message_search_repository.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';

/// The offline fallback. It searches only what this device has loaded, and
/// it matches the way the server does — every term present, the last one by
/// prefix (api-docs §5.4.1) — so being offline changes what is found, not
/// what counts as a match.
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
    store.remember('a', [message('a', 1, content: 'ship it')]);

    expect((await search('ship')).source, MessageSearchSource.localCache);
  });

  test('finds a message by its content, ignoring case', () async {
    store.remember('a', [message('a', 1, content: 'Ship it tomorrow')]);

    final result = await search('SHIP');

    expect(result.hits.single.message.seq, 1);
  });

  test('the last term matches by prefix, like the index does', () async {
    store.remember('a', [message('a', 1, content: 'подписали договор')]);

    expect((await search('догов')).hits, hasLength(1));
  });

  test('a prefix only works forwards', () async {
    store.remember('a', [message('a', 1, content: 'договоры подписаны')]);

    expect((await search('договорами')).hits, isEmpty);
  });

  test('every term has to be there', () async {
    store.remember('a', [
      message('a', 1, content: 'бюджет на договор'),
      message('a', 2, content: 'бюджет на квартал'),
    ]);

    final result = await search('бюджет догов');

    expect(result.hits.map((h) => h.seq), [1]);
  });

  test('the hit carries the piece of the message that matched', () async {
    store.remember('a', [
      message('a', 1, content: '${'x' * 300} needle ${'y' * 300}'),
    ]);

    final hit = (await search('needle')).hits.single;

    expect(hit.snippet.length, lessThan(200));
    final range = hit.highlights.single;
    expect(hit.snippet.substring(range.start, range.end), 'needle');
  });

  test('every term is picked out, not just the first', () async {
    store.remember('a', [message('a', 1, content: 'бюджет на договор')]);

    final hit = (await search('бюджет догов')).hits.single;

    expect(hit.highlights, hasLength(2));
    expect(
      hit.highlights
          .map((r) => hit.snippet.substring(r.start, r.end))
          .toList(),
      ['бюджет', 'догов'],
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

    expect((await search('ship')).hits.map((h) => h.seq), [3, 2, 1]);
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

  test('a query of nothing but punctuation finds nothing', () async {
    // The server treats those as term separators, so such a query has no
    // terms at all and comes back empty rather than as an error.
    store.remember('a', [message('a', 1, content: 'ship it')]);

    expect((await search(' & | ! ')).hits, isEmpty);
  });

  test('a page from the cache is the only page', () async {
    store.remember('a', [
      for (var seq = 1; seq <= 10; seq++)
        message('a', seq, content: 'ship $seq'),
    ]);

    final result = await repository.search('ship', limit: 4);

    result.match((failure) => fail('unexpected ${failure.message}'), (found) {
      expect(found.hits, hasLength(4));
      expect(found.hasNext, isFalse);
      expect(found.canLoadMore, isFalse);
    });
  });
}
