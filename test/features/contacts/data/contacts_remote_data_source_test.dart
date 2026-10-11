import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_remote_data_source.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// The wire side of `/contacts` (api-docs §4.7–4.13): every path with its
/// trailing slash, every field under the server's name.
void main() {
  late _MockApiClient api;
  late ContactsRemoteDataSourceImpl source;

  final row = <String, dynamic>{
    'owner_id': 7,
    'contact_id': 42,
    'first_name': 'Ваня',
    'last_name': null,
    'source': 2,
    'is_mutual': true,
    'is_favorite': false,
    'created_at': '2026-09-01T12:00:00Z',
    'updated_at': '2026-10-01T08:30:00Z',
    'profile': {
      'id': 42,
      'username': 'ivan',
      'display_name': 'Ivan Petrov',
      'avatars': {
        '64': {
          'jpg': 'https://cdn/42/64.jpg',
          'webp': 'https://cdn/42/64.webp',
        },
      },
    },
  };

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    api = _MockApiClient();
    source = ContactsRemoteDataSourceImpl(api);
  });

  group('GET /contacts/', () {
    test('first page: only the limit', () async {
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => const Right({
          'contacts': [],
          'has_next': false,
          'next_contact_id': null,
          'version': '2026-10-11T12:00:00Z',
        }),
      );

      final page = (await source.fetchPage()).getOrElse((_) => throw '');

      final captured = verify(
        () => api.get(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;
      expect(captured[0], '/contacts/');
      expect(captured[1], {'limit': 500});
      expect(page.version, '2026-10-11T12:00:00Z');
    });

    test('later pages and deltas carry the cursor and the mark', () async {
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => Right({
          'contacts': [row],
          'has_next': true,
          'next_contact_id': 42,
          'version': null,
        }),
      );

      final page = (await source.fetchPage(
        limit: 100,
        afterContactId: 41,
        updatedAfter: 'v1',
      )).getOrElse((_) => throw '');

      final captured = verify(
        () => api.get(
          any(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;
      expect(captured.single, {
        'limit': 100,
        'after_contact_id': 41,
        'updated_after': 'v1',
      });
      expect(page.hasNext, isTrue);
      expect(page.nextContactId, 42);
      expect(page.version, isNull);

      final contact = page.contacts.single;
      expect(contact.userId, 42);
      expect(contact.ownerId, 7);
      expect(contact.localName, 'Ваня');
      expect(contact.source, ContactSource.username);
      expect(contact.isMutual, isTrue);
      expect(contact.updatedAt, DateTime.utc(2026, 10, 1, 8, 30));
      expect(contact.profile?.displayName, 'Ivan Petrov');
      expect(contact.profile?.avatars['64']?['webp'], 'https://cdn/42/64.webp');
    });

    test('a contact without a profile reads, and is named by nobody', () async {
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => Right({
          'contacts': [
            {...row, 'first_name': null, 'profile': null, 'source': 99},
          ],
          'has_next': false,
        }),
      );

      final contact = (await source.fetchPage())
          .getOrElse((_) => throw '')
          .contacts
          .single;

      expect(contact.profile, isNull);
      expect(contact.bestName, isNull);
      expect(contact.source, ContactSource.unknown);
    });
  });

  test('POST /contacts/ sends exactly the fields given', () async {
    when(
      () => api.post(any(), data: any(named: 'data')),
    ).thenAnswer((_) async => Right(row));

    await source.add(username: 'ivan', firstName: 'Ваня');

    final captured = verify(
      () => api.post(captureAny(), data: captureAny(named: 'data')),
    ).captured;
    expect(captured[0], '/contacts/');
    expect(captured[1], {'username': 'ivan', 'first_name': 'Ваня'});
  });

  test('PATCH and DELETE address /contacts/{user_id}/', () async {
    when(
      () => api.patch(any(), data: any(named: 'data')),
    ).thenAnswer((_) async => Right(row));
    when(() => api.delete(any())).thenAnswer((_) async => const Right(null));

    await source.update(42, {'is_favorite': true});
    await source.delete(42);

    final patched = verify(
      () => api.patch(captureAny(), data: captureAny(named: 'data')),
    ).captured;
    expect(patched, [
      '/contacts/42/',
      {'is_favorite': true},
    ]);
    verify(() => api.delete('/contacts/42/')).called(1);
  });

  test('GET /contacts/search/ reads both halves of a hit', () async {
    when(
      () => api.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => Right({
        'items': [
          {'user_id': 42, 'profile': row['profile'], 'contact': row},
          {
            'user_id': 50,
            'profile': {'id': 50, 'username': 'stranger', 'avatars': {}},
            'contact': null,
          },
        ],
      }),
    );

    final hits = (await source.search('@ivan')).getOrElse((_) => throw '');

    final captured = verify(
      () => api.get(
        captureAny(),
        queryParameters: captureAny(named: 'queryParameters'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).captured;
    expect(captured[0], '/contacts/search/');
    expect(captured[1], {'query': '@ivan', 'limit': 50});
    expect(hits.first.isContact, isTrue);
    expect(hits.last.isContact, isFalse);
    expect(hits.last.profile?.username, 'stranger');
  });

  group('POST /contacts/import/', () {
    test('sends the Idempotency-Key and reads a synchronous answer', () async {
      when(
        () => api.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Right({
          'status': 'done',
          'accepted': 2,
          'matched': 1,
          'pending': 1,
          'invalid': 0,
          'contacts': [row],
        }),
      );

      final result = (await source.importContacts(const [
        ContactImportEntry(email: 'ivan@x.io', firstName: 'Ivan'),
        ContactImportEntry(email: 'anna@x.io'),
      ], idempotencyKey: 'key-1')).getOrElse((_) => throw '');

      final captured = verify(
        () => api.post(
          captureAny(),
          data: captureAny(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/contacts/import/');
      expect(captured[1], {
        'contacts': [
          {'email': 'ivan@x.io', 'first_name': 'Ivan'},
          {'email': 'anna@x.io'},
        ],
      });
      expect((captured[2] as Options).headers, {'Idempotency-Key': 'key-1'});
      expect(result.status, ContactImportStatus.done);
      expect(result.contacts.single.userId, 42);
    });

    test('reads a queued answer: counts zero, no contacts', () async {
      when(
        () => api.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => const Right({
          'status': 'queued',
          'accepted': 250,
          'matched': 0,
          'pending': 0,
          'invalid': 0,
          'contacts': [],
        }),
      );

      final result = (await source.importContacts(const [
        ContactImportEntry(email: 'a@x.io'),
      ], idempotencyKey: 'k')).getOrElse((_) => throw '');

      expect(result.status, ContactImportStatus.queued);
      expect(result.accepted, 250);
      expect(result.contacts, isEmpty);
    });
  });
}
