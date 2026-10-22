import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:chatix/features/profile/data/models/profile_photo_model.dart';
import 'package:chatix/features/profile/domain/entities/profile_photo.dart';
import 'package:chatix/features/settings/data/datasources/privacy_remote_data_source.dart';
import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// The three additions to `/profiles`: the public lookup by handle
/// (§4.3), the photo history (§4.5.1) and the privacy settings (§4.14).
void main() {
  late _MockApiClient api;
  late ProfileRemoteDataSourceImpl profiles;

  final profileJson = <String, dynamic>{
    'id': 42,
    'username': 'durov',
    'avatars': <String, dynamic>{},
    'specialization': null,
    'display_name': 'Pavel',
    'bio': null,
    'date_birthday': null,
    'skills': <dynamic>[],
    'links': <dynamic>[],
  };

  Map<String, dynamic> photoJson(String id, {bool main = false}) => {
    'id': id,
    'avatars': {
      '64': {'jpg': 'https://s3.example.com/profiles/42/$id/64.jpg?X-Sig=a'},
      '512': {
        'webp': 'https://s3.example.com/profiles/42/$id/512.webp?X-Sig=b',
      },
    },
    'is_main': main,
    'created_at': '2026-10-01T09:30:00Z',
  };

  setUp(() {
    api = _MockApiClient();
    profiles = ProfileRemoteDataSourceImpl(api);
  });

  String capturedGet() =>
      verify(
            () => api.get(
              captureAny(),
              queryParameters: any(named: 'queryParameters'),
            ),
          ).captured.single
          as String;

  group('GET /profiles/u/{username}/', () {
    test('asks by handle, slash at the end, and parses the profile', () async {
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => Right(profileJson));

      final result = await profiles.fetchProfileByUsername('durov');

      expect(capturedGet(), '/profiles/u/durov/');
      expect(result.getRight().toNullable()?.id, 42);
    });

    test('an old-style handle with a space is encoded into the path', () async {
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => Right(profileJson));

      await profiles.fetchProfileByUsername('Ivan Petrov');

      expect(capturedGet(), '/profiles/u/Ivan%20Petrov/');
    });
  });

  group('the photo history', () {
    test('GET /profiles/{id}/photos/ with the page asked for', () async {
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => Right({
          'items': [photoJson('p2', main: true), photoJson('p1')],
          'total': 2,
          'page': 1,
          'page_size': 100,
        }),
      );

      final result = await profiles.fetchPhotos(42, pageSize: 100);

      final call = verify(
        () => api.get(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;
      expect(call[0], '/profiles/42/photos/');
      expect(call[1], {'page': 1, 'page_size': 100});

      final page = result.getRight().toNullable()!;
      expect(page.total, 2);
      expect(page.items.map((photo) => photo.id), ['p2', 'p1']);
      expect(page.items.first.isMain, isTrue);
      expect(page.items.first.createdAt, DateTime.utc(2026, 10, 1, 9, 30));
    });

    test('making a photo main is a PUT on its own path', () async {
      when(() => api.put(any())).thenAnswer((_) async => const Right(null));

      await profiles.setMainPhoto('p1');

      expect(
        verify(() => api.put(captureAny())).captured.single,
        '/profiles/photos/p1/main/',
      );
    });

    test('deleting one is a DELETE on its own path', () async {
      when(() => api.delete(any())).thenAnswer((_) async => const Right(null));

      await profiles.deletePhoto('p1');

      expect(
        verify(() => api.delete(captureAny())).captured.single,
        '/profiles/photos/p1/',
      );
    });
  });

  group('ProfilePhoto', () {
    test('a picture is cached by its object key, not its signature', () {
      final photo = ProfilePhotoModel.fromJson(photoJson('p1'));
      final url = photo.bestUrl(512)!;

      expect(
        ProfilePhoto.cacheKeyOf(url),
        's3.example.com/profiles/42/p1/512.webp',
      );
      // The same object signed again is the same key.
      expect(
        ProfilePhoto.cacheKeyOf(url.replaceFirst('X-Sig=b', 'X-Sig=c')),
        ProfilePhoto.cacheKeyOf(url),
      );
    });

    test('a broken avatars map costs nothing but itself', () {
      final photo = ProfilePhotoModel.fromJson({
        'id': 'p9',
        'avatars': {
          '64': 'not a map',
          '256': {'jpg': 7, 'webp': 'u'},
        },
        'is_main': 'yes',
        'created_at': 'not a date',
      });

      expect(photo.avatars, {
        '256': {'webp': 'u'},
      });
      expect(photo.isMain, isFalse);
    });
  });

  group('/profiles/privacy/', () {
    late PrivacyRemoteDataSource privacy;

    setUp(() => privacy = PrivacyRemoteDataSource(api));

    test('reads with GET on the path without an id', () async {
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => const Right({
          'rules': {'photo': 'contacts'},
          'exceptions': <String, dynamic>{},
        }),
      );

      final result = await privacy.fetch();

      expect(capturedGet(), '/profiles/privacy/');
      expect(
        result.getRight().toNullable()?.visibilityOf(PrivacyRule.photo),
        PrivacyVisibility.contacts,
      );
    });

    test('changes with a partial PUT and reads back the answer', () async {
      when(() => api.put(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => const Right({
          'rules': {'calls': 'nobody'},
          'exceptions': <String, dynamic>{},
        }),
      );

      final result = await privacy.update(
        rules: {PrivacyRule.calls: PrivacyVisibility.nobody},
      );

      final call = verify(
        () => api.put(captureAny(), data: captureAny(named: 'data')),
      ).captured;
      expect(call[0], '/profiles/privacy/');
      expect(call[1], {
        'rules': {'calls': 'nobody'},
      });
      expect(
        result.getRight().toNullable()?.visibilityOf(PrivacyRule.calls),
        PrivacyVisibility.nobody,
      );
    });
  });
}
