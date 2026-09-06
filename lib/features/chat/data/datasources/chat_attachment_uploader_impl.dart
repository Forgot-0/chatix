import 'dart:io';

import 'package:chatix/features/chat/data/repositories/chat_attachment_uploader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/providers/network_providers.dart';

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
          headers: {
            Headers.contentTypeHeader: mimeType,
            Headers.contentLengthHeader: contentLength,
          },
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

bool get isWebPlatform => kIsWeb;
