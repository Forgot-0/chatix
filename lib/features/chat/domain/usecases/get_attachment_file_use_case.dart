import 'dart:io';

import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/core/storage/cache/attachment_file_cache.dart';
import 'package:chatix/features/chat/data/repositories/chat_attachment_downloader.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

/// An attachment as a file on this device, downloading it if need be.
///
/// The two facts from api-docs §5.5 this exists to reconcile: the link in
/// `AttachmentDTO.url` is dead after 300 seconds, and the bytes behind
/// `s3_key` never change. So the cache is keyed by `s3_key`, an expired link
/// is simply replaced by asking
/// `GET .../attachments/{id}/download-url/` for another one, and none of
/// that reaches the screen — the caller either gets a file or a failure.
class GetAttachmentFileUseCase {
  GetAttachmentFileUseCase(this._repository, this._downloader, this._cache);

  final ChatRepository _repository;
  final ChatAttachmentDownloader _downloader;
  final AttachmentFileCache _cache;

  Future<Either<Failure, File>> execute({
    required String chatId,
    required String messageId,
    required AttachmentEntity attachment,
    void Function(int received, int total)? onProgress,
    TransferCancellation? cancellation,
  }) async {
    final cached = await _cache.find(attachment.s3Key);
    if (cached != null) return Right(cached);

    // The link the message arrived with is worth one try: on a message that
    // just came in over the socket it is fresh, and that saves a round trip
    // per thumbnail in an album.
    final inline = attachment.url;
    if (inline != null && inline.isNotEmpty) {
      final first = await _downloader.download(
        url: inline,
        onProgress: onProgress,
        cancellation: cancellation,
      );

      final bytes = first.getRight().toNullable();
      if (bytes != null) {
        return Right(await _cache.store(attachment.s3Key, bytes));
      }

      final failure = first.getLeft().toNullable()!;
      if (!_isWorthRetrying(failure, cancellation)) return Left(failure);
    }

    final urlResult = await _repository.getAttachmentDownloadUrl(
      chatId,
      messageId,
      attachment.id,
    );

    final download = urlResult.getRight().toNullable();
    if (download == null) return Left(urlResult.getLeft().toNullable()!);

    final second = await _downloader.download(
      url: download.url,
      onProgress: onProgress,
      cancellation: cancellation,
    );

    final bytes = second.getRight().toNullable();
    if (bytes == null) return Left(second.getLeft().toNullable()!);

    return Right(await _cache.store(attachment.s3Key, bytes));
  }

  /// Whether a failed download is worth a second attempt with a fresh link.
  ///
  /// A refused signature is worth one (400/401/403 from the object store,
  /// see `expiredLinkStatusCodes`); anything else — no network, a timeout, a
  /// cancel — would fail exactly the same way twice.
  bool _isWorthRetrying(Failure failure, TransferCancellation? cancellation) {
    if (cancellation?.isCancelled ?? false) return false;
    if (failure is CancelledFailure) return false;

    final status = failure.statusCode;
    return status != null && expiredLinkStatusCodes.contains(status);
  }
}
