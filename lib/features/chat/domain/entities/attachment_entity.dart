import 'package:equatable/equatable.dart';

/// `AttachmentDTO.attachment_type` (api-docs §6.5). Drives which upload
/// limits apply: [image]/[video] share one bucket (≤50 MB, ≤10 per message),
/// [file] is its own (≤100 MB, ≤1 per message).
enum AttachmentType {
  image,
  video,
  file;

  String get wire => name;

  static AttachmentType fromWire(String? value) {
    return AttachmentType.values.firstWhere(
      (t) => t.name == value,
      // Unknown types are treated as a plain file — the strictest bucket
      // (1 per message), so an unexpected value can never let 10 oversized
      // uploads through the client-side check.
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

  const AttachmentUploadRequestEntity({
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    this.filePath,
    this.bytes,
  });

  @override
  List<Object?> get props => [filename, mimeType, fileSize, filePath, bytes];
}
