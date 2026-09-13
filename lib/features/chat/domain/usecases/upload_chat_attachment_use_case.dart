import 'dart:async';

import 'package:chatix/features/chat/data/repositories/chat_attachment_uploader.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

enum ChatAttachmentUploadStage { requesting, uploading, confirming, done }

class ChatAttachmentUploadProgress extends Equatable {
  final ChatAttachmentUploadStage stage;

  final int currentIndex;

  final int totalFiles;

  final int sentBytes;
  final int totalBytes;

  final List<String> uploadTokens;

  /// How far each selected file has got, 0..1, in selection order.
  ///
  /// The ring on a thumbnail is per file, not per batch: an album uploads
  /// one file at a time and the person watching wants to know which one is
  /// moving. Empty before the first byte goes out.
  final List<double> fileFractions;

  const ChatAttachmentUploadProgress({
    required this.stage,
    this.currentIndex = 0,
    this.totalFiles = 0,
    this.sentBytes = 0,
    this.totalBytes = 0,
    this.uploadTokens = const [],
    this.fileFractions = const [],
  });

  double? get fraction {
    if (stage == ChatAttachmentUploadStage.done) return 1;
    if (totalFiles == 0) return null;
    final perFile = 1 / totalFiles;
    final withinFile = totalBytes > 0 ? sentBytes / totalBytes : 0.0;
    return (currentIndex * perFile + withinFile * perFile).clamp(0.0, 1.0);
  }

  /// How far the file at [index] has got, or null when nothing is known
  /// about it yet.
  double? fractionOf(int index) {
    if (index < 0 || index >= fileFractions.length) return null;
    return fileFractions[index];
  }

  @override
  List<Object?> get props => [
    stage,
    currentIndex,
    totalFiles,
    sentBytes,
    totalBytes,
    uploadTokens,
    fileFractions,
  ];
}

class UploadChatAttachmentUseCase {
  final ChatRepository _repository;
  final ChatAttachmentUploader _uploader;

  UploadChatAttachmentUseCase(this._repository, this._uploader);

  /// Runs the three steps of api-docs §5.5 and reports on them as it goes.
  ///
  /// Progress arrives from the HTTP client as a callback rather than in
  /// step with the awaits, so the stream is driven by a controller instead
  /// of `async*`: a byte counter that only surfaced between files would be
  /// no counter at all.
  ///
  /// [cancellation] is passed straight through to the transfer in flight. A
  /// cancelled upload ends the stream with a `CancelledFailure`, which the
  /// UI reads as "the person pressed the button", not as an error.
  Stream<Either<Failure, ChatAttachmentUploadProgress>> execute(
    String chatId,
    List<AttachmentUploadRequestEntity> uploads, {
    TransferCancellation? cancellation,
  }) {
    final controller =
        StreamController<Either<Failure, ChatAttachmentUploadProgress>>();

    controller.onListen = () {
      _run(chatId, uploads, controller, cancellation).whenComplete(() {
        if (!controller.isClosed) controller.close();
      });
    };

    return controller.stream;
  }

  Future<void> _run(
    String chatId,
    List<AttachmentUploadRequestEntity> uploads,
    StreamController<Either<Failure, ChatAttachmentUploadProgress>> controller,
    TransferCancellation? cancellation,
  ) async {
    void emit(Either<Failure, ChatAttachmentUploadProgress> event) {
      if (!controller.isClosed) controller.add(event);
    }

    final validation = validate(uploads);
    if (validation != null) {
      emit(Left(validation));
      return;
    }

    final fractions = List<double>.filled(uploads.length, 0);

    emit(
      Right(
        ChatAttachmentUploadProgress(
          stage: ChatAttachmentUploadStage.requesting,
          totalFiles: uploads.length,
          fileFractions: List<double>.unmodifiable(fractions),
        ),
      ),
    );

    final ticketsResult = await _repository.requestAttachmentUpload(
      chatId,
      uploads,
    );
    final tickets = ticketsResult.getRight().toNullable();
    if (tickets == null) {
      emit(Left(ticketsResult.getLeft().toNullable()!));
      return;
    }

    if (tickets.length != uploads.length) {
      emit(
        Left(
          ServerFailure(
            message:
                'Upload could not be started: asked for ${uploads.length} '
                'upload slots but received ${tickets.length}',
          ),
        ),
      );
      return;
    }

    for (var i = 0; i < uploads.length; i++) {
      if (cancellation?.isCancelled ?? false) {
        emit(const Left(CancelledFailure(message: 'Upload cancelled')));
        return;
      }

      final upload = uploads[i];
      final ticket = tickets[i];

      emit(
        Right(
          ChatAttachmentUploadProgress(
            stage: ChatAttachmentUploadStage.uploading,
            currentIndex: i,
            totalFiles: uploads.length,
            totalBytes: upload.fileSize,
            fileFractions: List<double>.unmodifiable(fractions),
          ),
        ),
      );

      final putResult = await _uploader.upload(
        uploadUrl: ticket.uploadUrl,
        mimeType: upload.mimeType,
        contentLength: upload.fileSize,
        filePath: upload.filePath,
        bytes: upload.bytes,
        cancellation: cancellation,
        onProgress: (sent, total) {
          final of = total > 0 ? total : upload.fileSize;
          fractions[i] = of > 0 ? (sent / of).clamp(0.0, 1.0) : 0.0;

          emit(
            Right(
              ChatAttachmentUploadProgress(
                stage: ChatAttachmentUploadStage.uploading,
                currentIndex: i,
                totalFiles: uploads.length,
                sentBytes: sent,
                totalBytes: of,
                fileFractions: List<double>.unmodifiable(fractions),
              ),
            ),
          );
        },
      );

      if (putResult.isLeft()) {
        emit(Left(putResult.getLeft().toNullable()!));
        return;
      }

      fractions[i] = 1;
    }

    emit(
      Right(
        ChatAttachmentUploadProgress(
          stage: ChatAttachmentUploadStage.confirming,
          currentIndex: uploads.length,
          totalFiles: uploads.length,
          fileFractions: List<double>.unmodifiable(fractions),
        ),
      ),
    );

    final tokens = tickets.map((t) => t.uploadToken).toList();
    final confirmResult = await _repository.confirmAttachmentUpload(
      chatId,
      tokens,
    );
    if (confirmResult.isLeft()) {
      emit(Left(confirmResult.getLeft().toNullable()!));
      return;
    }

    emit(
      Right(
        ChatAttachmentUploadProgress(
          stage: ChatAttachmentUploadStage.done,
          currentIndex: uploads.length,
          totalFiles: uploads.length,
          uploadTokens: tokens,
          fileFractions: List<double>.unmodifiable(fractions),
        ),
      ),
    );
  }

  Failure? validate(List<AttachmentUploadRequestEntity> uploads) {
    if (uploads.isEmpty) {
      return const InputFailure(message: 'No files selected');
    }

    var mediaCount = 0;
    var fileCount = 0;
    final types = <AttachmentType>[];

    for (final upload in uploads) {
      final type = upload.resolvedType;
      if (type == null) {
        return InputFailure(
          message:
              '"${upload.filename}" can\'t be attached — '
              '${upload.mimeType} files are not supported',
        );
      }
      types.add(type);

      if (ChatAttachmentLimits.requiresExplicitAttachmentType(type) &&
          upload.attachmentType == null) {
        return InputFailure(
          message:
              '"${upload.filename}" must be attached with an explicit '
              '${type.wire} type',
        );
      }

      final allowedForType = switch (type) {
        AttachmentType.voice => ChatAttachmentLimits.voiceMimeTypes,
        AttachmentType.videoNote => ChatAttachmentLimits.videoNoteMimeTypes,
        AttachmentType.image ||
        AttachmentType.video ||
        AttachmentType.file => null,
      };
      if (allowedForType != null &&
          !allowedForType.contains(upload.mimeType.toLowerCase())) {
        return InputFailure(
          message:
              '${upload.mimeType} is not a supported format for a '
              '${type.wire} attachment',
        );
      }

      if (upload.fileSize <= 0) {
        return InputFailure(message: '"${upload.filename}" is empty');
      }

      final maxSize = ChatAttachmentLimits.maxSizeFor(type);
      if (upload.fileSize > maxSize) {
        return InputFailure(
          message:
              '"${upload.filename}" is '
              '${ChatAttachmentLimits.formatBytes(upload.fileSize)} — '
              'the limit for ${type.wire}s is '
              '${ChatAttachmentLimits.formatBytes(maxSize)}',
        );
      }

      if (upload.filePath == null && upload.bytes == null) {
        return InputFailure(
          message: '"${upload.filename}" could not be read from the device',
        );
      }

      switch (type) {
        case AttachmentType.file:
          fileCount++;
        case AttachmentType.image:
        case AttachmentType.video:
          mediaCount++;
        case AttachmentType.voice:
        case AttachmentType.videoNote:
          break;
      }
    }

    final exclusivity = ChatAttachmentLimits.exclusivityViolation(types);
    if (exclusivity != null) {
      return InputFailure(message: exclusivity);
    }

    if (mediaCount > ChatAttachmentLimits.maxMediaCount) {
      return InputFailure(
        message:
            'You can attach up to ${ChatAttachmentLimits.maxMediaCount} '
            'photos or videos per message ($mediaCount selected)',
      );
    }

    if (fileCount > ChatAttachmentLimits.maxFileCount) {
      return InputFailure(
        message:
            'You can attach only ${ChatAttachmentLimits.maxFileCount} '
            'document per message ($fileCount selected) — '
            'send the rest separately',
      );
    }

    if (fileCount > 0 && mediaCount > 0) {
      return const InputFailure(
        message:
            'A document can\'t be sent together with photos or videos — '
            'send them as separate messages',
      );
    }

    return null;
  }
}
