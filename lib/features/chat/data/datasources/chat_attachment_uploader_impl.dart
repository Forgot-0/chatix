import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/chat/data/datasources/chat_attachment_uploader.dart';

/// Implements step 2 of the attachment flow (api-docs §6.5): a **raw `PUT`**
/// of the file's bytes to the presigned `upload_url`, sent through the bare
/// [rawUploadDioProvider] instance.
///
/// The bare Dio matters as much as the verb. The presigned URL already carries
/// its signature in the query string, and S3/MinIO computes the signature over
/// a fixed set of headers — our main `ApiClient` would add
/// `Authorization: Bearer …` (making the request ambiguous and, on some
/// gateways, rejected outright), rewrite the path via
/// `TrailingSlashInterceptor` (invalidating the signature), and retry on
/// failure (re-sending 100 MB).
///
/// ### Why a stream and not `File.readAsBytes()`
///
/// A document may be 100 MB (api-docs §6.5). Buffering that in memory next to
/// the image previews the picker already holds is how mid-range Android
/// devices get OOM-killed mid-send, so [filePath] uploads are streamed from
/// disk in chunks. [bytes] is the web fallback, where no `File` path exists.
///
/// `Content-Length` is set explicitly from the caller's `contentLength`
/// (the same `file_size` the backend recorded at step 1): a streamed body has
/// no implicit length, and S3 rejects a chunked PUT without it.
class ChatAttachmentUploaderImpl implements ChatAttachmentUploader {
  final Dio _dio;
  final FileFactory _fileFactory;

  ChatAttachmentUploaderImpl(this._dio, {FileFactory? fileFactory})
    : _fileFactory = fileFactory ?? File.new;

  @override
  Future<Either<Failure, void>> upload({
    required String uploadUrl,
    required String mimeType,
    required int contentLength,
    String? filePath,
    List<int>? bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (filePath == null && bytes == null) {
      return const Left(
        InputFailure(message: 'Nothing to upload: no file path and no bytes'),
      );
    }

    try {
      // A path wins over in-memory bytes: streaming keeps peak memory flat
      // regardless of file size.
      final Object body;
      if (filePath != null) {
        final file = _fileFactory(filePath);
        body = file.openRead();
      } else {
        body = Stream<List<int>>.value(bytes!);
      }

      await _dio.put<dynamic>(
        uploadUrl,
        data: body,
        onSendProgress: onProgress,
        options: Options(
          // ⚠️ The file's own MIME type — NOT a multipart boundary
          // (api-docs §6.5). The backend's async validation pass compares the
          // stored object against what it was promised at step 1; a wrong
          // Content-Type there flips the attachment to `error`.
          headers: {
            Headers.contentTypeHeader: mimeType,
            Headers.contentLengthHeader: contentLength,
          },
          // S3/MinIO answers a successful PUT with an empty body; asking Dio
          // for JSON would make it try to decode nothing and throw.
          responseType: ResponseType.plain,
        ),
      );
      return const Right(null);
    } on DioException catch (e) {
      return Left(_mapError(e));
    } on FileSystemException catch (e) {
      return Left(
        InputFailure(
          message: 'Could not read the file from the device: ${e.message}',
        ),
      );
    }
  }

  /// Storage errors arrive as S3 XML, not our `{error: {...}}` envelope
  /// (api-docs §2), so there is nothing feature-specific to parse — only the
  /// class of problem, by status code.
  ///
  /// `403` is called out separately because it has one overwhelmingly likely
  /// cause here: the presigned URL's 3600 s lifetime ran out (api-docs §6.5),
  /// and the fix is to restart from step 1 rather than to retry the PUT.
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
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == HttpStatus.forbidden) {
          return ServerFailure(
            message:
                'The upload link has expired — please attach the file again',
            statusCode: status,
          );
        }
        return ServerFailure(
          message: 'File storage rejected the upload',
          statusCode: status,
        );
      case DioExceptionType.unknown:
        if (e.error is SocketException) return const NetworkFailure();
        return const NetworkFailure(message: 'Unknown network error');
      default:
        return const ServerFailure(message: 'Unknown error occurred');
    }
  }
}

final chatAttachmentUploaderProvider = Provider<ChatAttachmentUploader>((ref) {
  return ChatAttachmentUploaderImpl(ref.watch(rawUploadDioProvider));
});

/// `kIsWeb` re-exported for callers deciding between [filePath] and `bytes`
/// when building an `AttachmentUploadRequestEntity`: on web there is no
/// readable path, so bytes are the only option.
bool get isWebPlatform => kIsWeb;
