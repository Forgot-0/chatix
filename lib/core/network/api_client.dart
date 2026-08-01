import 'dart:async';
import 'dart:io';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_path.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  /// Absolute health-check URL outside `/api/v1` (api-docs §1.1).
  String get healthCheckUrl => AppConstants.healthCheckUrl;

  Future<Either<Failure, dynamic>> getHealth() async {
    try {
      final response = await _dio.get<dynamic>(
        healthCheckUrl,
        options: Options(
          extra: const {'skipTrailingSlash': true},
        ),
      );
      return Right(response.data);
    } on DioException catch (e) {
      return Left(_handleError(e));
    }
  }

  Future<Either<Failure, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        buildPath(path),
        queryParameters: queryParameters,
      );
      return Right(response.data);
    } on DioException catch (e) {
      return Left(_handleError(e));
    }
  }

  Future<Either<Failure, dynamic>> post(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        buildPath(path),
        data: data,
        options: options,
      );
      return Right(response.data);
    } on DioException catch (e) {
      return Left(_handleError(e));
    }
  }

  Future<Either<Failure, dynamic>> put(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        buildPath(path),
        data: data,
        options: options,
      );
      return Right(response.data);
    } on DioException catch (e) {
      return Left(_handleError(e));
    }
  }

  /// Partial update. Distinct from [put] on purpose — the chats module uses
  /// `PATCH` for chat settings, member roles and bans (api-docs §6.2–§6.4),
  /// where omitted fields mean "leave unchanged", while `/profiles/` uses a
  /// full `PUT` (§4.4). Sending one where the other is expected either wipes
  /// fields or 405s.
  Future<Either<Failure, dynamic>> patch(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        buildPath(path),
        data: data,
        options: options,
      );
      return Right(response.data);
    } on DioException catch (e) {
      return Left(_handleError(e));
    }
  }

  Future<Either<Failure, dynamic>> delete(
    String path, {
    Options? options,
  }) async {
    try {
      final response = await _dio.delete<dynamic>(
        buildPath(path),
        options: options,
      );
      return Right(response.data);
    } on DioException catch (e) {
      return Left(_handleError(e));
    }
  }

  Failure _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutFailure(statusCode: e.response?.statusCode);
      case DioExceptionType.cancel:
        return const ServerFailure(message: 'Request cancelled');
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return const NetworkFailure();
        }
        return const NetworkFailure(message: 'Unknown network error');
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        return _handleBadResponse(e);
      default:
        return const ServerFailure(message: 'Unknown error occurred');
    }
  }

  Failure _handleBadResponse(DioException e) {
    final response = e.response;
    if (response == null) {
      return const NetworkFailure();
    }

    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    if (statusCode == 429) {
      final message = data is Map && data['detail'] != null
          ? data['detail'].toString()
          : 'Too Many Requests';
      return RateLimitFailure(message: message);
    }

    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        return ApiFailure(
          code: error['code'] as String? ?? 'UNKNOWN',
          message: error['message'] as String? ?? 'Unknown error',
          detail: error['detail'],
          status: statusCode,
        );
      }
    }

    return ServerFailure(
      message: 'Unknown error occurred',
      statusCode: statusCode,
    );
  }
}
