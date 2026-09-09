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
    'avatars': <String, dynamic>{},
    'specialization': null,
    'display_name': null,
    'bio': null,
    'date_birthday': null,
    'skills': <dynamic>[],
    'contacts': <dynamic>[],
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

    test('parses the DTO straight from the body, unwrapped', () async {
      stubGet(tProfileJson);

      final result = await dataSource.fetchProfile(7);

      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()?.id, 7);
    });
  });
}
