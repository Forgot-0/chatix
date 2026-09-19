import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
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
        () => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => response);

      final result = await apiClient.get('/test');

      verify(() => mockDio.get<dynamic>(tPath));
      expect(result, Right(tResponseData));
    });

    test(
      'get should return Left(ApiFailure) for application error envelope',
      () async {
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
        result.fold((failure) {
          expect(failure, isA<ApiFailure>());
          final apiFailure = failure as ApiFailure;
          expect(apiFailure.code, 'NOT_FOUND_USER');
          expect(apiFailure.status, 404);
        }, (_) => fail('Should have returned Left'));
      },
    );

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

    test('a 429 that carries an error envelope keeps its code', () async {
      // Two different things answer 429 (api-docs §2.2): the rate limiter,
      // with a bare `detail`, and application throttles like slow mode, with
      // the ordinary envelope. Collapsing both into RateLimitFailure loses
      // `retry_after`, which is the only thing the composer can count down.
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: tPath),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: tPath),
            statusCode: 429,
            data: {
              'error': {
                'code': 'SLOW_MODE_LIMIT',
                'message': 'Slow mode',
                'detail': {'chat_id': 'c1', 'retry_after': 12},
              },
              'status': 429,
            },
          ),
        ),
      );

      final result = await apiClient.post('/test');

      result.fold((failure) {
        expect(failure, isA<ApiFailure>());
        final api = failure as ApiFailure;
        expect(api.code, 'SLOW_MODE_LIMIT');
        expect(api.status, 429);
        expect((api.detail as Map)['retry_after'], 12);
      }, (_) => fail('Should have returned Left'));
    });

    // `VALIDATION` is the one code whose `detail` is a list rather than an
    // object (api-docs §2.2). Anything that reaches for `detail['field']`
    // without checking throws on it, so the parse has to hand the array
    // through untouched.
    test('422 VALIDATION carries an array detail, not an object', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: tPath),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: tPath),
            statusCode: 422,
            data: {
              'error': {
                'code': 'VALIDATION',
                'message': 'Validation exception',
                'detail': [
                  {
                    'loc': ['body', 'password'],
                    'msg': 'String should have at least 8 characters',
                    'type': 'string_too_short',
                  },
                  {
                    'loc': ['body', 'username'],
                    'msg': 'Field required',
                    'type': 'missing',
                  },
                ],
              },
              'status': 422,
            },
          ),
        ),
      );

      final result = await apiClient.post('/test');

      result.fold((failure) {
        expect(failure, isA<ApiFailure>());
        final api = failure as ApiFailure;
        expect(api.code, 'VALIDATION');
        expect(api.status, 422);

        final detail = api.detail;
        expect(detail, isA<List<dynamic>>());
        expect((detail as List).length, 2);
        expect((detail.first as Map)['type'], 'string_too_short');
        expect((detail.first as Map)['loc'], ['body', 'password']);
      }, (_) => fail('Should have returned Left'));
    });

    test('a VALIDATION array does not break the UI sentence for it', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // The presentation layer reads `detail` as a map for most codes; the
      // array must not make it throw on the way to a message.
      const failure = ApiFailure(
        code: 'VALIDATION',
        message: 'Validation exception',
        detail: [
          {
            'loc': ['body', 'password'],
            'msg': 'too short',
            'type': 'string_too_short',
          },
        ],
        status: 422,
      );

      expect(
        () => friendlyFailureMessage(failure, l10n: l10n),
        returnsNormally,
      );
      expect(
        friendlyFailureMessage(failure, l10n: l10n),
        'Some of the details are invalid. Please check and try again.',
      );
    });
  });
}
