import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/profile/domain/repositories/avatar_uploader.dart';

/// Implements the raw presigned-**PUT** upload (api-docs §4.5 step 2, §10.4)
/// with the bare [rawUploadDioProvider] instance — no `baseUrl`, no cookie/
/// auth/retry/trailing-slash interceptors, so it can't accidentally send our
/// `Authorization` header or mangle the presigned [url] the way the main
/// `ApiClient` would. Both matter: an extra header is at best ignored by
/// storage, and a trailing slash appended to a signed URL breaks its
/// signature outright.
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
      // The whole request: raw bytes as the body, nothing wrapping them.
      // No multipart, no form fields, no query parameters of our own — the
      // presigned URL already encodes the key, the method and the expiry.
      // Same shape as `ChatAttachmentUploaderImpl` — the two flows are one
      // mechanism (§10.4) and any divergence here is a bug waiting to happen.
      await _dio.put<dynamic>(
        url,
        data: Stream<List<int>>.value(bytes),
        options: Options(
          headers: {
            // ⚠️ The image's own MIME type, NOT a multipart boundary. The
            // background job sniffs the stored object's real type anyway
            // (§4.5), but storing it with the wrong Content-Type makes the
            // served avatar undisplayable in a browser.
            Headers.contentTypeHeader: contentType,
            // A streamed body has no implicit length and S3/MinIO rejects a
            // chunked presigned PUT, so it has to be stated.
            Headers.contentLengthHeader: bytes.length,
          },
          // Storage answers a successful PUT with an empty body (XML on
          // failure); asking Dio for JSON would make it decode nothing.
          responseType: ResponseType.plain,
        ),
      );
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
        // The most likely 403 here is not a permissions problem but an
        // expired URL: the presign is only valid for 90 seconds (§4.5), so a
        // slow connection or a backgrounded app can genuinely run it out.
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
