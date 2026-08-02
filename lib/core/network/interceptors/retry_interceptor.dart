import 'dart:io';
import 'package:chatix/core/utils/logger.dart';
import 'package:dio/dio.dart';

/// Interceptor that retries failed requests
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final List<Duration> retryDelays;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 5),
    ],
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_shouldRetry(err)) {
      final attempt = err.requestOptions.headers['retry_attempt'] ?? 0;

      if (attempt < maxRetries && attempt < retryDelays.length) {
        final delay = retryDelays[attempt];
        Logger.info(
          'RetryInterceptor: attempt ${attempt + 1}/$maxRetries for '
          '${err.requestOptions.path} in ${delay.inSeconds}s',
        );

        // Update retry attempt count
        err.requestOptions.headers['retry_attempt'] = attempt + 1;

        // Wait before retrying
        await Future.delayed(delay);

        try {
          // Clone the request and retry
          final options = Options(
            method: err.requestOptions.method,
            headers: err.requestOptions.headers,
            contentType: err.requestOptions.contentType,
            responseType: err.requestOptions.responseType,
            followRedirects: err.requestOptions.followRedirects,
            listFormat: err.requestOptions.listFormat,
            receiveTimeout: err.requestOptions.receiveTimeout,
            sendTimeout: err.requestOptions.sendTimeout,
            validateStatus: err.requestOptions.validateStatus,
            extra: err.requestOptions.extra,
          );

          final response = await dio.request(
            err.requestOptions.path,
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
            cancelToken: err.requestOptions.cancelToken,
            options: options,
            onSendProgress: err.requestOptions.onSendProgress,
            onReceiveProgress: err.requestOptions.onReceiveProgress,
          );

          return handler.resolve(response);
        } catch (e, stackTrace) {
          // The retry failed too. The *original* error is what propagates —
          // it is the one the caller's error mapping was written against —
          // but the retry's own exception must not vanish: when a retry
          // fails for a different reason than the original (a 500 where the
          // first attempt timed out, say), that difference is the only clue
          // in the logs about what actually went wrong.
          Logger.warning(
            'RetryInterceptor: attempt ${attempt + 1}/$maxRetries for '
            '${err.requestOptions.method} ${err.requestOptions.path} failed '
            '($e); propagating the original ${err.type}',
          );
          if (e is! DioException) {
            // A non-Dio throw here means the retry machinery itself broke,
            // not the network — that is a bug, not a flaky connection.
            Logger.error(
              'RetryInterceptor: non-DioException while retrying '
              '${err.requestOptions.path}',
              e,
              stackTrace,
            );
          }
          return super.onError(err, handler);
        }
      }
    }

    return super.onError(err, handler);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        (err.type == DioExceptionType.unknown &&
            err.error != null &&
            err.error is SocketException);
  }
}
