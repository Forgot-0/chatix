import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockResponse extends Mock implements Response {}

void main() {
  late ApiClient apiClient;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    apiClient = ApiClient(mockDio);
  });

  group('ApiClient', () {
    const tPath = '/test/';
    final tResponseData = {'success': true};

    test('get should perform a GET request and return Right(data)', () async {
      final response = MockResponse();
      when(() => response.data).thenReturn(tResponseData);
      when(() => response.statusCode).thenReturn(200);
      when(
        () =>
            mockDio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => response);

      final result = await apiClient.get('/test');

      verify(() => mockDio.get<dynamic>(tPath));
      expect(result, Right(tResponseData));
    });

    test('get should return Left(ApiFailure) for application error envelope', () async {
      when(
        () => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: tPath),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: tPath),
            statusCode: 404,
            data: {
              'error': {
                'code': 'NOT_FOUND_USER',
                'message': 'User not found',
                'detail': {'user_by': '123', 'user_field': 'id'},
              },
              'status': 404,
            },
          ),
        ),
      );

      final result = await apiClient.get('/test');

      expect(result, isA<Left<Failure, dynamic>>());
      result.fold(
        (failure) {
          expect(failure, isA<ApiFailure>());
          final apiFailure = failure as ApiFailure;
          expect(apiFailure.code, 'NOT_FOUND_USER');
          expect(apiFailure.status, 404);
        },
        (_) => fail('Should have returned Left'),
      );
    });

    test('get should return Left(RateLimitFailure) for HTTP 429', () async {
      when(
        () => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: tPath),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: tPath),
            statusCode: 429,
            data: {'detail': 'Too Many Requests'},
          ),
        ),
      );

      final result = await apiClient.get('/test');

      expect(result, isA<Left<Failure, dynamic>>());
      result.fold(
        (failure) => expect(failure, isA<RateLimitFailure>()),
        (_) => fail('Should have returned Left'),
      );
    });
  });
}
