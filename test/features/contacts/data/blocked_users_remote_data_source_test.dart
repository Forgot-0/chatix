import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/features/contacts/data/datasources/blocked_users_remote_data_source.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// The wire side of the block list (api-docs §4.13): every path with its
/// trailing slash, `/contacts/blocked/` before any `{user_id}`.
void main() {
  late _MockApiClient api;
  late BlockedUsersRemoteDataSourceImpl source;

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    api = _MockApiClient();
    source = BlockedUsersRemoteDataSourceImpl(api);
  });

  group('GET /contacts/blocked/', () {
    test('the first page asks only for the limit', () async {
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => const Right({
          'blocked': [],
          'has_next': false,
          'next_target_id': null,
        }),
      );

      final page = (await source.fetchPage()).getOrElse((_) => throw '');

      final captured = verify(
        () => api.get(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;
      expect(captured[0], '/contacts/blocked/');
      expect(captured[1], {'limit': BlockedUsersApi.screenPageSize});
      expect(page.users, isEmpty);
      expect(page.hasNext, isFalse);
    });

    test('a later page carries the cursor; entries are read', () async {
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => const Right({
          'blocked': [
            {
              'target_id': 42,
              'created_at': '2026-10-01T08:30:00Z',
              'profile': {
                'id': 42,
                'username': 'ivan',
                'display_name': 'Ivan Petrov',
                'avatars': {},
              },
            },
            // A person whose profile is gone still has a row.
            {
              'target_id': 43,
              'created_at': '2026-10-02T08:30:00Z',
              'profile': null,
            },
          ],
          'has_next': true,
          'next_target_id': 43,
        }),
      );

      final page = (await source.fetchPage(
        limit: 500,
        afterTargetId: 41,
      )).getOrElse((_) => throw '');

      final query = verify(
        () => api.get(
          any(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured.single;
      expect(query, {'limit': 500, 'after_target_id': 41});

      expect(page.users.map((user) => user.userId), [42, 43]);
      expect(page.users.first.profile?.displayName, 'Ivan Petrov');
      expect(page.users.first.since, DateTime.utc(2026, 10, 1, 8, 30));
      expect(page.users.last.profile, isNull);
      expect(page.hasNext, isTrue);
      expect(page.nextTargetId, 43);
    });

    test('a failure comes back as it was', () async {
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => const Left(NetworkFailure()));

      expect(await source.fetchPage(), const Left(NetworkFailure()));
    });
  });

  group('block and unblock', () {
    test('POST /contacts/{id}/block/ — a 204 has no body to read', () async {
      when(() => api.post(any())).thenAnswer((_) async => const Right(null));

      expect((await source.block(42)).isRight(), isTrue);
      verify(() => api.post('/contacts/42/block/')).called(1);
    });

    test('DELETE /contacts/{id}/block/', () async {
      when(() => api.delete(any())).thenAnswer((_) async => const Right(''));

      expect((await source.unblock(42)).isRight(), isTrue);
      verify(() => api.delete('/contacts/42/block/')).called(1);
    });
  });
}
