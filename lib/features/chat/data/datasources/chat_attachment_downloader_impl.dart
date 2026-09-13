import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/chat/data/repositories/chat_attachment_downloader.dart';

class ChatAttachmentDownloaderImpl implements ChatAttachmentDownloader {
  ChatAttachmentDownloaderImpl(this._dio);

  final Dio _dio;

  @override
  Future<Either<Failure, List<int>>> download({
    required String url,
    void Function(int received, int total)? onProgress,
    TransferCancellation? cancellation,
  }) async {
    final token = CancelToken();
    cancellation?.whenCancelled.then((_) {
      if (!token.isCancelled) token.cancel('cancelled by the reader');
    });
    if (cancellation?.isCancelled ?? false) {
      return const Left(CancelledFailure(message: 'Download cancelled'));
    }

    try {
      final response = await _dio.get<Uint8List>(
        url,
        cancelToken: token,
        onReceiveProgress: onProgress,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return const Left(
          ServerFailure(message: 'The file came back empty from storage'),
        );
      }
      return Right(bytes);
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
        return const CancelledFailure(message: 'Download cancelled');
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        return ServerFailure(
          message: 'File storage refused the download',
          statusCode: e.response?.statusCode,
        );
      case DioExceptionType.unknown:
        if (e.error is SocketException) return const NetworkFailure();
        return const NetworkFailure(message: 'Unknown network error');
      default:
        return const ServerFailure(message: 'Unknown error occurred');
    }
  }
}

final chatAttachmentDownloaderProvider = Provider<ChatAttachmentDownloader>((
  ref,
) {
  return ChatAttachmentDownloaderImpl(ref.watch(rawUploadDioProvider));
});
