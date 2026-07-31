import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/profile/domain/repositories/avatar_uploader.dart';

/// Implements the raw presigned-POST upload (api-docs §4.5 step 2) with the
/// bare [rawUploadDioProvider] instance — no `baseUrl`, no cookie/auth/
/// retry/trailing-slash interceptors, so it can't accidentally send our
/// `Authorization` header or mangle the presigned [url] the way the main
/// `ApiClient` would.
class AvatarUploaderImpl implements AvatarUploader {
  final Dio _dio;

  AvatarUploaderImpl(this._dio);

  @override
  Future<Either<Failure, void>> upload({
    required String url,
    required Map<String, String> fields,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    try {
      // Standard S3/MinIO presigned-POST form: every policy field from
      // `fields` as-is, plus the file itself under "file" — order matters
      // for some S3-compatible servers (the file field must come last),
      // so `fields` is spread before adding "file".
      final formData = FormData.fromMap({
        ...fields,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ),
      });

      await _dio.post<dynamic>(url, data: formData);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapError(e));
    }
  }

  /// S3/MinIO error bodies are XML, not our `{error: {...}}` envelope
  /// (api-docs §2) — there's nothing feature-specific to parse out of them,
  /// so this only distinguishes network/timeout issues from "the storage
  /// service rejected the request", by status code.
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
        return ServerFailure(
          message: 'Avatar storage rejected the upload',
          statusCode: e.response?.statusCode,
        );
      default:
        return const ServerFailure(message: 'Unknown error occurred');
    }
  }
}

final avatarUploaderProvider = Provider<AvatarUploader>((ref) {
  return AvatarUploaderImpl(ref.watch(rawUploadDioProvider));
});
