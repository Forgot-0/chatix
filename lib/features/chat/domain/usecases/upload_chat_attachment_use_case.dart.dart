import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/repositories/chat_attachment_uploader.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

/// Which step of the upload is running, for a progress indicator
/// (api-docs §6.5). Mirrors `AvatarUploadStage` from the profile feature.
enum ChatAttachmentUploadStage {
  /// Step 1 — asking the backend for upload tickets.
  requesting,

  /// Step 2 — PUTting raw bytes straight to storage. The long one.
  uploading,

  /// Step 3 — telling the backend the bytes have landed.
  confirming,

  /// All tokens are confirmed and may go into `sendMessage`.
  done,
}

/// Progress of the upload as a whole, emitted by
/// [UploadChatAttachmentUseCase.execute].
class ChatAttachmentUploadProgress extends Equatable {
  final ChatAttachmentUploadStage stage;

  /// Index of the file currently being PUT (0-based), only meaningful during
  /// [ChatAttachmentUploadStage.uploading].
  final int currentIndex;

  final int totalFiles;

  /// Bytes sent / total for the current file, when the transport reports it.
  final int sentBytes;
  final int totalBytes;

  /// Populated once [stage] is [ChatAttachmentUploadStage.done]: exactly the
  /// tokens to hand to `sendMessage(uploadTokens: ...)`.
  final List<String> uploadTokens;

  const ChatAttachmentUploadProgress({
    required this.stage,
    this.currentIndex = 0,
    this.totalFiles = 0,
    this.sentBytes = 0,
    this.totalBytes = 0,
    this.uploadTokens = const [],
  });

  /// 0..1 across the whole batch, or `null` when it can't be known yet.
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

/// Drives the **three-request** attachment upload of api-docs §6.5 behind one
/// call, so screens never have to know it isn't a single upload:
///
///  1. `requestAttachmentUpload` → one `{upload_token, upload_url,
///     attachment_type, expires_in}` ticket per file.
///  2. For each file, a raw **`PUT`** of the bytes to that ticket's
///     `upload_url`, with the file's own `Content-Type`.
///     ⚠️ Not a multipart `POST` — that's the *avatar* flow (§4.5). See
///     [ChatAttachmentUploader] for what breaks if the two are confused.
///  3. `confirmAttachmentUpload(tokens)` → `202 Accepted`.
///
/// **After step 3 the caller may immediately call `sendMessage` with these
/// same `upload_tokens`** (api-docs §6.5 step 4). The 202 only means "queued":
/// the backend validates the bytes and fills in `width`/`height`/
/// `duration_seconds` asynchronously, so the attachments initially come back
/// on the message with `attachment_status: pending` and flip to `success`
/// later. Readiness is announced by the WS `attachment_success` event (§7.4),
/// which this REST-only layer does not observe — waiting for it here is not
/// required and would just delay the message.
///
/// [execute] returns a `Stream` (like `UploadAvatarUseCase`) so a screen can
/// drive a real progress bar. The stream ends with
/// `Right(ChatAttachmentUploadProgress(stage: done, uploadTokens: [...]))` or
/// with a single `Left(Failure)` at the first step that failed — nothing is
/// retried automatically, and a partially uploaded batch is simply abandoned
/// (the unconfirmed tokens expire on their own, so no cleanup call exists).
class UploadChatAttachmentUseCase {
  final ChatRepository _repository;
  final ChatAttachmentUploader _uploader;

  UploadChatAttachmentUseCase(this._repository, this._uploader);

  Stream<Either<Failure, ChatAttachmentUploadProgress>> execute(
    String chatId,
    List<AttachmentUploadRequestEntity> uploads,
  ) async* {
    // ── Validate everything BEFORE the first byte moves (api-docs §6.5) ──
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

    // ── Step 1 ──
    final ticketsResult = await _repository.requestAttachmentUpload(
      chatId,
      uploads,
    );
    final tickets = ticketsResult.getRight().toNullable();
    if (tickets == null) {
      yield Left(ticketsResult.getLeft().toNullable()!);
      return;
    }

    // The backend returns one ticket per requested upload, in order. If that
    // ever stops holding, pairing them by index would silently upload file A
    // to file B's URL — so bail out instead of guessing.
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

    // ── Step 2 — raw PUT per file ──
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

    // ── Step 3 ──
    final tokens = tickets.map((t) => t.uploadToken).toList();
    final confirmResult = await _repository.confirmAttachmentUpload(
      chatId,
      tokens,
    );
    if (confirmResult.isLeft()) {
      yield Left(confirmResult.getLeft().toNullable()!);
      return;
    }

    // Step 4 (sending the message with these tokens) belongs to the caller —
    // see the class doc: it may happen immediately, no waiting required.
    yield Right(
      ChatAttachmentUploadProgress(
        stage: ChatAttachmentUploadStage.done,
        currentIndex: uploads.length,
        totalFiles: uploads.length,
        uploadTokens: tokens,
      ),
    );
  }

  /// Checks a selection against the api-docs §6.5 limits, returning `null`
  /// when it is acceptable or the [Failure] to show otherwise.
  ///
  /// Exposed separately from [execute] so a screen can grey out the send
  /// button (or reject a drag-and-drop) the moment files are picked, rather
  /// than at send time. Errors name the offending file and the actual limit —
  /// "too large" without either is useless to the person who has to fix it.
  Failure? validate(List<AttachmentUploadRequestEntity> uploads) {
    if (uploads.isEmpty) {
      // `EMPTY_ATTACHMENT_UPLOAD_REQUEST` server-side.
      return const InputFailure(message: 'No files selected');
    }

    var mediaCount = 0;
    var fileCount = 0;

    for (final upload in uploads) {
      final type = ChatAttachmentLimits.typeOf(upload.mimeType);
      if (type == null) {
        return InputFailure(
          message:
              '"${upload.filename}" can\'t be attached — '
              '${upload.mimeType} files are not supported',
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

      // Images and videos share one bucket; documents have their own.
      if (type == AttachmentType.file) {
        fileCount++;
      } else {
        mediaCount++;
      }
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

    // The document bucket allows exactly 1 attachment *per message*, so a
    // document cannot travel alongside photos — worth saying explicitly,
    // since the server would only report a generic count violation.
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
