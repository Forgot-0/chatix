import 'package:chatix/features/chat/data/repositories/chat_attachment_uploader.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

enum ChatAttachmentUploadStage {
  requesting,

  uploading,

  confirming,

  done,
}

class ChatAttachmentUploadProgress extends Equatable {
  final ChatAttachmentUploadStage stage;

  final int currentIndex;

  final int totalFiles;

  final int sentBytes;
  final int totalBytes;

  final List<String> uploadTokens;

  const ChatAttachmentUploadProgress({
    required this.stage,
    this.currentIndex = 0,
    this.totalFiles = 0,
    this.sentBytes = 0,
    this.totalBytes = 0,
    this.uploadTokens = const [],
  });

  double? get fraction {
    if (stage == ChatAttachmentUploadStage.done) return 1;
    if (totalFiles == 0) return null;
    final perFile = 1 / totalFiles;
    final withinFile = totalBytes > 0 ? sentBytes / totalBytes : 0.0;
    return (currentIndex * perFile + withinFile * perFile).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
    stage,
    currentIndex,
    totalFiles,
    sentBytes,
    totalBytes,
    uploadTokens,
  ];
}

class UploadChatAttachmentUseCase {
  final ChatRepository _repository;
  final ChatAttachmentUploader _uploader;

  UploadChatAttachmentUseCase(this._repository, this._uploader);

  Stream<Either<Failure, ChatAttachmentUploadProgress>> execute(
    String chatId,
    List<AttachmentUploadRequestEntity> uploads,
  ) async* {
    final validation = validate(uploads);
    if (validation != null) {
      yield Left(validation);
      return;
    }

    yield Right(
      ChatAttachmentUploadProgress(
        stage: ChatAttachmentUploadStage.requesting,
        totalFiles: uploads.length,
      ),
    );

    final ticketsResult = await _repository.requestAttachmentUpload(
      chatId,
      uploads,
    );
    final tickets = ticketsResult.getRight().toNullable();
    if (tickets == null) {
      yield Left(ticketsResult.getLeft().toNullable()!);
      return;
    }

    if (tickets.length != uploads.length) {
      yield Left(
        ServerFailure(
          message:
              'Upload could not be started: asked for ${uploads.length} '
              'upload slots but received ${tickets.length}',
        ),
      );
      return;
    }

    for (var i = 0; i < uploads.length; i++) {
      final upload = uploads[i];
      final ticket = tickets[i];

      yield Right(
        ChatAttachmentUploadProgress(
          stage: ChatAttachmentUploadStage.uploading,
          currentIndex: i,
          totalFiles: uploads.length,
          totalBytes: upload.fileSize,
        ),
      );

      final putResult = await _uploader.upload(
        uploadUrl: ticket.uploadUrl,
        mimeType: upload.mimeType,
        contentLength: upload.fileSize,
        filePath: upload.filePath,
        bytes: upload.bytes,
      );

      if (putResult.isLeft()) {
        yield Left(putResult.getLeft().toNullable()!);
        return;
      }
    }

    yield Right(
      ChatAttachmentUploadProgress(
        stage: ChatAttachmentUploadStage.confirming,
        currentIndex: uploads.length,
        totalFiles: uploads.length,
      ),
    );

    final tokens = tickets.map((t) => t.uploadToken).toList();
    final confirmResult = await _repository.confirmAttachmentUpload(
      chatId,
      tokens,
    );
    if (confirmResult.isLeft()) {
      yield Left(confirmResult.getLeft().toNullable()!);
      return;
    }

    yield Right(
      ChatAttachmentUploadProgress(
        stage: ChatAttachmentUploadStage.done,
        currentIndex: uploads.length,
        totalFiles: uploads.length,
        uploadTokens: tokens,
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
