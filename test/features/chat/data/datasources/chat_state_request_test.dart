import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/features/chat/data/datasources/chat_rest_data_source.dart';

class MockApiClient extends Mock implements ApiClient {}

/// `UpdateChatStateRequest` says what to change by what the body contains: a
/// field that is absent is left alone, a field present as null is cleared
/// (api-docs §5.2). Sending the wrong one of those silently wipes a draft or
/// silently keeps a mute.
void main() {
  late MockApiClient api;
  late ChatRestDataSourceImpl dataSource;

  setUp(() {
    api = MockApiClient();
    dataSource = ChatRestDataSourceImpl(api);

    when(
      () => api.patch(any(), data: any(named: 'data')),
    ).thenAnswer((_) async => const Right(<String, dynamic>{}));
  });

  Future<Map<String, dynamic>> bodyOf(
    Future<void> Function() call, {
    String path = '/chats/c1/state/',
  }) async {
    await call();

    final captured = verify(
      () => api.patch(path, data: captureAny(named: 'data')),
    ).captured;

    return captured.single as Map<String, dynamic>;
  }

  test('pinning sends the flag and nothing else', () async {
    final body = await bodyOf(
      () => dataSource.updateChatState('c1', pinned: true),
    );

    expect(body, {'pinned': true});
  });

  test('unpinning is false, not an absent field', () async {
    final body = await bodyOf(
      () => dataSource.updateChatState('c1', pinned: false),
    );

    expect(body, {'pinned': false});
  });

  test('archiving and unarchiving travel the same way', () async {
    expect(
      await bodyOf(() => dataSource.updateChatState('c1', archived: true)),
      {'archived': true},
    );
  });

  test('a mute deadline is sent as UTC', () async {
    final body = await bodyOf(
      () => dataSource.updateChatState(
        'c1',
        notificationsMutedUntil: DateTime.utc(2026, 5, 1, 12),
      ),
    );

    expect(body['notifications_muted_until'], '2026-05-01T12:00:00.000Z');
  });

  test('unmuting sends the field as null, which is what clears it', () async {
    final body = await bodyOf(
      () => dataSource.updateChatState(
        'c1',
        clearNotificationsMutedUntil: true,
      ),
    );

    expect(body.containsKey('notifications_muted_until'), isTrue);
    expect(body['notifications_muted_until'], isNull);
  });

  test('a draft is sent as text and cleared as null', () async {
    expect(
      await bodyOf(() => dataSource.updateChatState('c1', draft: 'on my way')),
      {'draft': 'on my way'},
    );

    final cleared = await bodyOf(
      () => dataSource.updateChatState('c1', clearDraft: true),
    );
    expect(cleared.containsKey('draft'), isTrue);
    expect(cleared['draft'], isNull);
  });

  test('what was not asked for is not in the body at all', () async {
    final body = await bodyOf(
      () => dataSource.updateChatState('c1', pinned: true),
    );

    expect(body.containsKey('archived'), isFalse);
    expect(body.containsKey('notifications_muted_until'), isFalse);
    expect(body.containsKey('draft'), isFalse);
  });

  test('the path ends in a slash, like every other one', () async {
    await dataSource.updateChatState('c1', pinned: true);

    verify(
      () => api.patch('/chats/c1/state/', data: any(named: 'data')),
    ).called(1);
  });

  group('the two lists', () {
    setUp(() {
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'has_next': false,
          'chats': <dynamic>[],
          'next_date': null,
          'next_chat_id': null,
        }),
      );
    });

    Future<Map<String, dynamic>> queryOf(Future<void> Function() call) async {
      await call();

      final captured = verify(
        () => api.get('/chats/', queryParameters: captureAny(named: 'queryParameters')),
      ).captured;

      return captured.last as Map<String, dynamic>;
    }

    test('the main list asks for the unarchived set', () async {
      final query = await queryOf(() => dataSource.fetchChats());

      expect(query['archived'], isFalse);
    });

    test('the archive is a request of its own', () async {
      final query = await queryOf(
        () => dataSource.fetchChats(archived: true),
      );

      expect(query['archived'], isTrue);
    });

    test('the cursor is both halves of it', () async {
      final query = await queryOf(
        () => dataSource.fetchChats(
          lastChatId: 'c9',
          lastActivityAt: DateTime.utc(2026, 3, 10),
        ),
      );

      expect(query['last_chat_id'], 'c9');
      expect(query['last_activity_at'], '2026-03-10T00:00:00.000Z');
    });
  });
}
