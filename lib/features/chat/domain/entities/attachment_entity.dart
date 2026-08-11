import 'package:equatable/equatable.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';

/// `AttachmentDTO.attachment_type` (api-docs §6.5). Drives which upload
/// limits apply:
///
/// * [image]/[video] share one bucket (≤50 MB, ≤10 per message);
/// * [file] is its own (≤100 MB, ≤1 per message);
/// * [voice] (≤20 MB, ≤600 s) and [videoNote] (≤40 MB, ≤60 s, ≤640 px) are
///   **exclusive**: one per message and never alongside anything else — see
///   [ChatAttachmentLimits.exclusivityViolation].
enum AttachmentType {
  image,
  video,
  file,
  voice,

  /// ⚠️ `video_note` on the wire — the one value whose Dart name and JSON
  /// name differ, hence the explicit [wire] override below. Parsing it by
  /// `name` alone would silently degrade every video note to [file].
  videoNote;

  String get wire => switch (this) {
    AttachmentType.videoNote => 'video_note',
    _ => name,
  };

  static AttachmentType fromWire(String? value) {
    return AttachmentType.values.firstWhere(
      (t) => t.wire == value,
      // Unknown types are treated as a plain file — the strictest *shared*
      // bucket (1 per message), so an unexpected value can never let 10
      // oversized uploads through the client-side check. Deliberately not
      // `voice`/`videoNote`: those are exclusive types whose presence changes
      // how the whole message is validated, and guessing one of them for an
      // unrecognised string would reject legitimate mixed selections.
      orElse: () => AttachmentType.file,
    );
  }
}

/// `AttachmentDTO.attachment_status` (api-docs §6.5) — three values.
///
/// Lifecycle: the row is created [pending] by the upload-request step, and
/// the backend flips it to [success] (filling `width`/`height`/
/// `duration_seconds`) or [error] asynchronously after `confirm`. There is
/// no WS event for the failure case (api-docs §6.5), so [error] is only ever
/// observed by re-reading the message.
enum AttachmentStatus {
  pending,
  success,
  error;

  String get wire => name;

  static AttachmentStatus fromWire(String? value) {
    return AttachmentStatus.values.firstWhere(
      (s) => s.name == value,
      // Fail towards "still processing" rather than "broken": an unknown
      // status shows a spinner instead of a red error on a good file.
      orElse: () => AttachmentStatus.pending,
    );
  }
}

/// `AttachmentDTO` (api-docs §6.5).
class AttachmentEntity extends Equatable {
  final String id;

  /// `null` while the attachment has been uploaded but not yet bound to a
  /// message (i.e. between `confirm` and `sendMessage`).
  final String? messageId;

  final String chatId;
  final int uploaderId;
  final AttachmentType attachmentType;
  final AttachmentStatus attachmentStatus;

  /// Pre-signed view URL, when the backend chose to inline one. `null` means
  /// "ask for one" — `GET .../download-url/` (api-docs §6.5). Valid for
  /// [urlExpiresIn] seconds, so it must not be cached beyond that.
  final String? url;
  final int? urlExpiresIn;

  final String s3Key;
  final String mimeType;
  final String originalFilename;
  final int size;

  /// Filled in by the backend's async validation pass — `null` until
  /// [attachmentStatus] becomes [AttachmentStatus.success], and permanently
  /// `null` for non-media attachments.
  final int? width;
  final int? height;
  final int? durationSeconds;

  final DateTime createdAt;

  const AttachmentEntity({
    required this.id,
    required this.messageId,
    required this.chatId,
    required this.uploaderId,
    required this.attachmentType,
    required this.attachmentStatus,
    required this.url,
    required this.urlExpiresIn,
    required this.s3Key,
    required this.mimeType,
    required this.originalFilename,
    required this.size,
    required this.width,
    required this.height,
    required this.durationSeconds,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    messageId,
    chatId,
    uploaderId,
    attachmentType,
    attachmentStatus,
    url,
    urlExpiresIn,
    s3Key,
    mimeType,
    originalFilename,
    size,
    width,
    height,
    durationSeconds,
    createdAt,
  ];
}

/// `AttachmentDownloadUrlDTO` (api-docs §6.5). The URL lives 300 s; treat
/// [expiresIn] as authoritative and re-request rather than caching.
class AttachmentDownloadUrlEntity extends Equatable {
  final String attachmentId;
  final String url;
  final int expiresIn;

  const AttachmentDownloadUrlEntity({
    required this.attachmentId,
    required this.url,
    required this.expiresIn,
  });

  @override
  List<Object?> get props => [attachmentId, url, expiresIn];
}

/// One entry of the `POST /chats/{id}/attachments/upload-requests/` response
/// (api-docs §6.5 step 1). ⚠️ That response is a **bare array**, not an
/// object wrapper.
class AttachmentUploadTicketEntity extends Equatable {
  /// Needed twice more: at `confirm` (step 3) and in `SendMessageRequest.
  /// upload_tokens` (step 4).
  final String uploadToken;

  /// Pre-signed **PUT** URL, valid [expiresIn] seconds (3600). Raw bytes go
  /// straight here — no multipart, no auth header (api-docs §6.5 step 2).
  final String uploadUrl;

  final AttachmentType attachmentType;
  final int expiresIn;

  const AttachmentUploadTicketEntity({
    required this.uploadToken,
    required this.uploadUrl,
    required this.attachmentType,
    required this.expiresIn,
  });

  @override
  List<Object?> get props => [
    uploadToken,
    uploadUrl,
    attachmentType,
    expiresIn,
  ];
}

/// A local file the caller wants to attach, as handed to
/// `requestAttachmentUpload` (`uploads[]` of api-docs §6.5 step 1) — plus
/// the bytes/path needed for the step-2 PUT, which never reach the backend.
class AttachmentUploadRequestEntity extends Equatable {
  final String filename;
  final String mimeType;
  final int fileSize;

  /// Absolute path on disk. Either this or [bytes] must be set; a path is
  /// preferred because it lets the PUT stream the file instead of holding a
  /// 100 MB buffer in memory.
  final String? filePath;

  /// In-memory contents — the only option on web, where `File` paths don't
  /// exist.
  final List<int>? bytes;

  /// Explicit `uploads[].attachment_type` for step 1 (api-docs §6.5).
  ///
  /// `null` means "let the backend infer it from the MIME", which is correct
  /// and normal for images, videos and documents.
  ///
  /// ⚠️ **Mandatory** for [AttachmentType.voice] and
  /// [AttachmentType.videoNote]: that inference only ever yields
  /// `image`/`video`/`file`, so a voice message sent without this field is
  /// stored as a plain audio *file* and a video note as a plain *video* —
  /// silently, with the wrong size limits and the wrong bubble. [resolvedType]
  /// and `UploadChatAttachmentUseCase.validate` enforce that it is set.
  final AttachmentType? attachmentType;

  const AttachmentUploadRequestEntity({
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    this.filePath,
    this.bytes,
    this.attachmentType,
  });

  /// Convenience constructor for a voice message — sets the mandatory
  /// [attachmentType] so a caller cannot forget it.
  const AttachmentUploadRequestEntity.voice({
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    this.filePath,
    this.bytes,
  }) : attachmentType = AttachmentType.voice;

  /// Convenience constructor for a video note — see
  /// [AttachmentUploadRequestEntity.voice].
  const AttachmentUploadRequestEntity.videoNote({
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    this.filePath,
    this.bytes,
  }) : attachmentType = AttachmentType.videoNote;

  /// The type this upload will actually be: the explicit [attachmentType] when
  /// the caller set one, otherwise whatever the MIME resolves to — the same
  /// inference the backend performs. `null` means the MIME is not accepted at
  /// all.
  AttachmentType? get resolvedType =>
      attachmentType ?? ChatAttachmentLimits.typeOf(mimeType);

  @override
  List<Object?> get props => [
    filename,
    mimeType,
    fileSize,
    filePath,
    bytes,
    attachmentType,
  ];
}
