import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';

/// Client-side transcription of the attachment limits in api-docs §6.5.
///
/// These exist so the app can reject a bad selection **before** spending a
/// round-trip (and before making the user wait through a 100 MB upload that
/// the backend will refuse), and so the file/image pickers can be configured
/// to only offer selectable files in the first place. The server enforces the
/// same rules authoritatively — `400 ATTACHMENT_VALIDATION` /
/// `ATTACHMENT_LIMIT_EXCEEDED` — so this is a UX shortcut, never a security
/// boundary.
///
/// ⚠️ The two buckets do **not** share limits, and the difference is not just
/// the size cap:
///
/// | bucket | max size | max per message |
/// |---|---|---|
/// | image + video | 50 MB each | 10 |
/// | file | 100 MB | **1** |
///
/// A single message therefore cannot mix a document with photos, because the
/// document bucket allows exactly one attachment total.
abstract final class ChatAttachmentLimits {
  /// 50 MB — images and videos (api-docs §6.5).
  static const int maxMediaSizeBytes = 50 * 1024 * 1024;

  /// 100 MB — plain files (api-docs §6.5).
  static const int maxFileSizeBytes = 100 * 1024 * 1024;

  /// Up to 10 images/videos per message.
  static const int maxMediaCount = 10;

  /// Exactly one document per message.
  static const int maxFileCount = 1;

  static const Set<String> imageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  static const Set<String> videoMimeTypes = {
    'video/mp4',
    'video/quicktime',
    'video/webm',
  };

  static const Set<String> fileMimeTypes = {
    'application/pdf',
    'application/zip',
    'text/plain',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };

  /// Every MIME type the backend accepts — hand this to `file_picker` as its
  /// allow-list so unsupported files can't be chosen at all.
  static Set<String> get allowedMimeTypes => {
    ...imageMimeTypes,
    ...videoMimeTypes,
    ...fileMimeTypes,
  };

  /// File extensions matching [allowedMimeTypes], for pickers that filter by
  /// extension (`FilePicker.custom` + `allowedExtensions`) rather than MIME.
  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'mp4',
    'mov',
    'webm',
    'pdf',
    'zip',
    'txt',
    'doc',
    'docx',
    'xlsx',
  ];

  static bool isAllowedMimeType(String mimeType) =>
      allowedMimeTypes.contains(mimeType.toLowerCase());

  /// Which bucket a MIME type belongs to, or `null` if it isn't allowed at
  /// all. This mirrors the `attachment_type` the backend will assign at step
  /// 1, so the client's count/size checks agree with the server's.
  static AttachmentType? typeOf(String mimeType) {
    final mime = mimeType.toLowerCase();
    if (imageMimeTypes.contains(mime)) return AttachmentType.image;
    if (videoMimeTypes.contains(mime)) return AttachmentType.video;
    if (fileMimeTypes.contains(mime)) return AttachmentType.file;
    return null;
  }

  /// Per-attachment size cap for [type].
  static int maxSizeFor(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
      case AttachmentType.video:
        return maxMediaSizeBytes;
      case AttachmentType.file:
        return maxFileSizeBytes;
    }
  }

  /// Per-message count cap for [type]'s bucket.
  static int maxCountFor(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
      case AttachmentType.video:
        return maxMediaCount;
      case AttachmentType.file:
        return maxFileCount;
    }
  }

  /// `12.4 MB` — for size-limit error messages and upload progress labels.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
