import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:chatix/features/chat/data/datasources/message_cache_store.dart';
import 'package:chatix/features/chat/data/repositories/local_message_search_repository.dart';
import 'package:chatix/features/chat/data/repositories/remote_message_search_repository.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/domain/repositories/message_search_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockMessageSearchRepository extends Mock
    implements MessageSearchRepository {}

/// `GET /chats/messages/search/` is a static path in the chats router with a
/// keyset cursor over message ids (api-docs §5.4.1).
void main() {
  late MockApiClient api;
  late RemoteMessageSearchRepository repository;

  setUp(() {
    api = MockApiClient();
    repository = RemoteMessageSearchRepository(ChatRestDataSourceImpl(api));
  });

  Map<String, dynamic> messageJson(String id, String content) => {
    'id': id,
    'chat_id': 'c1',
    'seq': 4,
    'author_id': 9,
    'type': 'text',
    'content': content,
    'created_at': '2026-03-10T10:00:00Z',
    'is_edited': false,
  };

  void answerWith(Map<String, dynamic> body) {
    when(
      () => api.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => Right(body));
  }

  test('asks the static path, with the query as a parameter', () async {
    answerWith({'has_next': false, 'items': <dynamic>[], 'next_message_id': null});

    await repository.search('ship', chatId: 'c1', limit: 30);

    final captured = verify(
      () => api.get(
        '/chats/messages/search/',
        queryParameters: captureAny(named: 'queryParameters'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).captured;

    final query = captured.single as Map<String, dynamic>;
    expect(query['q'], 'ship');
    expect(query['chat_id'], 'c1');
    expect(query['limit'], 30);
    expect(query.containsKey('last_message_id'), isFalse);
  });

  test('the cursor is the id of the last message of the page', () async {
    answerWith({'has_next': false, 'items': <dynamic>[], 'next_message_id': null});

    await repository.search('ship', lastMessageId: 'm-9');

    final captured = verify(
      () => api.get(
        any(),
        queryParameters: captureAny(named: 'queryParameters'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).captured;

    expect((captured.single as Map<String, dynamic>)['last_message_id'], 'm-9');
  });

  test('hits carry the chat preview the answer came with', () async {
    answerWith({
      'has_next': true,
      'next_message_id': 'm-1',
      'items': [
        {
          'message': messageJson('m-1', 'ship it tomorrow'),
          'chat': {
            'id': 'c1',
            'type': 'group',
            'name': 'Design team',
            'avatar_url': 'https://cdn.example.com/a.jpg?sig=1',
            'avatar_s3_key': 'chats/c1/avatar.jpg',
          },
        },
      ],
    });

    final result = await repository.search('ship');

    result.match((failure) => fail('unexpected ${failure.message}'), (found) {
      expect(found.source, MessageSearchSource.server);
      expect(found.hasNext, isTrue);
      expect(found.nextMessageId, 'm-1');

      final hit = found.hits.single;
      expect(hit.chat?.name, 'Design team');
      expect(hit.chat?.type, ChatType.group);
      expect(hit.chat?.avatarS3Key, 'chats/c1/avatar.jpg');
      expect(hit.snippet, 'ship it tomorrow');
      expect(hit.highlights, hasLength(1));
    });
  });

  test('an item without a chat is still a result', () async {
    answerWith({
      'has_next': false,
      'next_message_id': null,
      'items': [
        {'message': messageJson('m-1', 'ship it'), 'chat': null},
      ],
    });

    final result = await repository.search('ship');

    expect(result.getRight().toNullable()?.hits.single.chat, isNull);
  });

  group('when the server cannot be reached', () {
    late InMemoryMessageCacheStore cache;
    late MockMessageSearchRepository remote;
    late OfflineFallbackMessageSearchRepository fallback;

    setUp(() {
      cache = InMemoryMessageCacheStore()
        ..remember('c1', [
          MessageEntity(
            id: 'm-1',
            chatId: 'c1',
            seq: 4,
            authorId: 9,
            type: MessageType.text,
            content: 'ship it tomorrow',
            replyToId: null,
            forwardedFromChatId: null,
            forwardedFromMessageId: null,
            forwardedFromAuthorId: null,
            isEdited: false,
            createdAt: DateTime.utc(2026, 3, 10),
          ),
        ]);

      remote = MockMessageSearchRepository();
      fallback = OfflineFallbackMessageSearchRepository(
        remote: remote,
        local: LocalMessageSearchRepository(cache),
      );
    });

    void remoteAnswers(Either<Failure, MessageSearchResult> answer) {
      when(
        () => remote.search(
          any(),
          chatId: any(named: 'chatId'),
          limit: any(named: 'limit'),
          lastMessageId: any(named: 'lastMessageId'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => answer);
    }

    test('what is on the device answers instead, and says so', () async {
      remoteAnswers(const Left(NetworkFailure()));

      final result = await fallback.search('ship');

      result.match((failure) => fail('unexpected ${failure.message}'), (found) {
        expect(found.source, MessageSearchSource.localCache);
        expect(found.hits, hasLength(1));
      });
    });

    test('a timeout falls back the same way', () async {
      remoteAnswers(const Left(TimeoutFailure()));

      final result = await fallback.search('ship');

      expect(
        result.getRight().toNullable()?.source,
        MessageSearchSource.localCache,
      );
    });

    test('a refusal is not hidden behind a worse answer', () async {
      // A rate limit or a 422 is something to show, not something to paper
      // over with a fraction of the history.
      remoteAnswers(const Left(RateLimitFailure()));

      final result = await fallback.search('ship');

      expect(result.getLeft().toNullable(), isA<RateLimitFailure>());
    });

    test('an empty answer from the server is the answer', () async {
      remoteAnswers(const Right(MessageSearchResult.empty));

      final result = await fallback.search('ship');

      result.match((failure) => fail('unexpected ${failure.message}'), (found) {
        expect(found.isEmpty, isTrue);
        expect(found.source, MessageSearchSource.server);
      });
    });
  });
}
