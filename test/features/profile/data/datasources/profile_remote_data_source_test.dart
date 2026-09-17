import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/features/profile/data/datasources/profile_remote_data_source.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late ProfileRemoteDataSourceImpl dataSource;
  late MockApiClient apiClient;

  final tProfileJson = <String, dynamic>{
    'id': 7,
    'username': 'ivan',
    'avatars': <String, dynamic>{},
    'specialization': null,
    'display_name': null,
    'bio': null,
    'date_birthday': null,
    'skills': <dynamic>[],
    // api-docs §4.3: the DTO field is `links`, not the pre-rename `contacts`.
    'links': <dynamic>[
      <String, dynamic>{'profile_id': 7, 'provider': 'github', 'contact': 'me'},
    ],
  };

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    apiClient = MockApiClient();
    dataSource = ProfileRemoteDataSourceImpl(apiClient);
  });

  void stubGet(Object? responseData) {
    when(
      () =>
          apiClient.get(any(), queryParameters: any(named: 'queryParameters')),
    ).thenAnswer((_) async => Right(responseData));
  }

  String capturedGetPath() {
    final captured = verify(
      () => apiClient.get(
        captureAny(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).captured;
    return captured.single as String;
  }

  group('profiles (api-docs §4.3)', () {
    test('fetchProfile addresses the numeric id, never a "my" alias', () async {
      stubGet(tProfileJson);

      await dataSource.fetchProfile(7);

      // api-docs §4 defines only `/profiles/` and `/profiles/{profile_id}/`.
      // `/profiles/my/` does not exist: FastAPI matches it as profile_id="my"
      // and Pydantic rejects the non-int with 422 VALIDATION.
      expect(capturedGetPath(), '/profiles/7/');
    });

    test('the own-profile id is just another id on the same path', () async {
      stubGet(tProfileJson);

      await dataSource.fetchProfile(1);

      expect(capturedGetPath(), '/profiles/1/');
    });

    test('carries the handle, which is never null (api-docs §4.3)', () async {
      stubGet(tProfileJson);

      final result = await dataSource.fetchProfile(7);

      // The one identifier every profile has: `display_name` is optional and
      // not unique, `username` is neither.
      expect(result.getRight().toNullable()?.username, 'ivan');
    });

    test('parses the DTO straight from the body, unwrapped', () async {
      stubGet(tProfileJson);

      final result = await dataSource.fetchProfile(7);

      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()?.id, 7);
    });

    test('fetchMyProfile uses the GetOrCreate route, not an id', () async {
      stubGet(tProfileJson);

      final result = await dataSource.fetchMyProfile();

      // api-docs §4.1: `/profiles/my/` is declared above `/{profile_id}/` and
      // creates the row when the auth.user.verified consumer has not yet.
      expect(capturedGetPath(), '/profiles/my/');
      expect(result.getRight().toNullable()?.id, 7);
    });

    test('reads profile links from `links` (api-docs §4.6 rename)', () async {
      stubGet(tProfileJson);

      final result = await dataSource.fetchProfile(7);

      final profile = result.getRight().toNullable();
      expect(profile?.contacts.single.provider, 'github');
    });

    test('a page of profiles parses the same DTO', () async {
      stubGet(<String, dynamic>{
        'items': <dynamic>[tProfileJson],
        'total': 1,
        'page': 1,
        'page_size': 20,
      });

      final result = await dataSource.fetchProfiles(q: 'iv');

      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()?.items.single.id, 7);
    });
  });

  group('profile links (api-docs §4.6)', () {
    test('addContact posts to /links/, not the pre-rename path', () async {
      when(
        () => apiClient.post(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => const Right(null));

      await dataSource.addContact(7, provider: 'github', contact: 'me');

      final captured = verify(
        () => apiClient.post(captureAny(), data: any(named: 'data')),
      ).captured;
      expect(captured.single, '/profiles/7/links/');
    });

    test('removeContact deletes /links/{provider}/', () async {
      when(() => apiClient.delete(any())).thenAnswer(
        (_) async => const Right(null),
      );

      await dataSource.removeContact(7, provider: 'github');

      final captured = verify(() => apiClient.delete(captureAny())).captured;
      expect(captured.single, '/profiles/7/links/github/');
    });
  });

  group('updateProfile — PUT is not a patch (api-docs §4.4)', () {
    void stubPut() {
      when(
        () => apiClient.put(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => const Right(null));
    }

    Map<String, dynamic> capturedPutBody() {
      final captured = verify(
        () => apiClient.put(any(), data: captureAny(named: 'data')),
      ).captured;
      return captured.single as Map<String, dynamic>;
    }

    test('sends every field, with nulls spelled out rather than omitted', () {
      stubPut();

      dataSource.updateProfile(
        7,
        specialization: null,
        displayName: 'Jane',
        bio: null,
        skills: const [],
        dateBirthday: null,
      );

      final body = capturedPutBody();

      // The handler assigns the body onto the row as it stands, so a key
      // that is absent is not "unchanged" — the old value survives and the
      // user's deletion is silently lost.
      expect(body.keys, containsAll(<String>[
        'specialization',
        'display_name',
        'bio',
        'skills',
        'date_birthday',
      ]));
      expect(body['specialization'], isNull);
      expect(body['bio'], isNull);
      expect(body['date_birthday'], isNull);
      expect(body['display_name'], 'Jane');
      expect(body['skills'], isEmpty);
    });

    test('addresses the profile by id, with the mandatory trailing slash', () {
      stubPut();

      dataSource.updateProfile(
        7,
        specialization: null,
        displayName: null,
        bio: null,
        skills: const [],
        dateBirthday: null,
      );

      final captured = verify(
        () => apiClient.put(captureAny(), data: any(named: 'data')),
      ).captured;
      expect(captured.single, '/profiles/7/');
    });
  });
}
