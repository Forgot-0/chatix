import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/profile/domain/repositories/avatar_uploader.dart';

class AvatarUploaderImpl implements AvatarUploader {
  final Dio _dio;

  AvatarUploaderImpl(this._dio);

  @override
  Future<Either<Failure, void>> upload({
    required String url,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      await _dio.put<dynamic>(
        url,
        data: Stream<List<int>>.value(bytes),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: bytes.length,
          },
          responseType: ResponseType.plain,
        ),
      );
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapError(e));
    }
  }

  Failure _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutFailure(statusCode: e.response?.statusCode);
      case DioExceptionType.cancel:
        return const ServerFailure(message: 'Upload cancelled');
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return const NetworkFailure();
        }
        return const NetworkFailure(message: 'Unknown network error');
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        return ServerFailure(
          message: status == 403
              ? 'The upload link expired — please try again'
              : 'Avatar storage rejected the upload',
          statusCode: status,
        );
      default:
        return const ServerFailure(message: 'Unknown error occurred');
    }
  }
}

final avatarUploaderProvider = Provider<AvatarUploader>((ref) {
  return AvatarUploaderImpl(ref.watch(rawUploadDioProvider));
});
