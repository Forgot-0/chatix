import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';

abstract final class ChatAttachmentLimits {
  static const int maxMediaSizeBytes = 50 * 1024 * 1024;

  static const int maxFileSizeBytes = 100 * 1024 * 1024;

  static const int maxVoiceSizeBytes = 20 * 1024 * 1024;

  static const int maxVideoNoteSizeBytes = 40 * 1024 * 1024;

  static const int maxMediaCount = 10;

  static const int maxFileCount = 1;

  static const int maxVoiceCount = 1;

  static const int maxVideoNoteCount = 1;

  static const int maxVoiceDurationSeconds = 600;

  /// When the recorder starts saying out loud how little is left.
  ///
  /// Thirty seconds before the cap: long enough to finish a sentence and
  /// send deliberately, rather than being cut off mid-word at 600 and left
  /// holding a recording that ends where the limit did.
  static const int voiceWarnAfterSeconds = 570;

  static const int maxVideoNoteDurationSeconds = 60;

  /// The video-note frame cap, measured on the **short** side.
  ///
  /// Which side is not in api-docs §5.5 — it says only "≤ 640 px" — and it
  /// is the whole difference between an ordinary Android 480p capture being
  /// usable and being thrown away: 720×480 is over 640 lengthways and
  /// comfortably under it across. It is the short side, confirmed against
  /// the backend, and it is written down here because getting it wrong is
  /// not a 400 with a code to read but `attachment_status: "error"` with
  /// `resolution_limit_exceeded` kept server-side, arriving after the
  /// message has been sent.
  static const int maxVideoNoteResolutionPx = 640;

  static const Set<String> imageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  static const Set<String> videoMimeTypes = {
    'video/mp4',
    'video/webm',
    'video/quicktime',
    'video/x-msvideo',
  };

  static const Set<String> fileMimeTypes = {
    'application/pdf',
    'application/zip',
    'application/x-zip-compressed',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain',
    'text/csv',
  };

  static const Set<String> voiceMimeTypes = {
    'audio/ogg',
    'audio/opus',
    'audio/mpeg',
    'audio/mp4',
    'audio/aac',
    'audio/webm',
    'audio/x-m4a',
  };

  static const Set<String> videoNoteMimeTypes = {
    'video/mp4',
    'video/webm',
    'video/quicktime',
  };

  static Set<String> get allowedMimeTypes => {
    ...imageMimeTypes,
    ...videoMimeTypes,
    ...fileMimeTypes,
  };

  static const List<String> allowedExtensions = [
    ...mediaExtensions,
    ...fileExtensions,
  ];

  static const List<String> mediaExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'heic',
    'heif',
    'mp4',
    'webm',
    'mov',
    'avi',
  ];

  static const List<String> fileExtensions = [
    'pdf',
    'zip',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'txt',
    'csv',
  ];

  static bool isAllowedMimeType(String mimeType) =>
      allowedMimeTypes.contains(mimeType.toLowerCase());

  static AttachmentType? typeOf(String mimeType) {
    final mime = mimeType.toLowerCase();
    if (imageMimeTypes.contains(mime)) return AttachmentType.image;
    if (videoMimeTypes.contains(mime)) return AttachmentType.video;
    if (fileMimeTypes.contains(mime)) return AttachmentType.file;
    return null;
  }

  static int maxSizeFor(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
      case AttachmentType.video:
        return maxMediaSizeBytes;
      case AttachmentType.file:
        return maxFileSizeBytes;
      case AttachmentType.voice:
        return maxVoiceSizeBytes;
      case AttachmentType.videoNote:
        return maxVideoNoteSizeBytes;
    }
  }

  static int maxCountFor(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
      case AttachmentType.video:
        return maxMediaCount;
      case AttachmentType.file:
        return maxFileCount;
      case AttachmentType.voice:
        return maxVoiceCount;
      case AttachmentType.videoNote:
        return maxVideoNoteCount;
    }
  }

  static int? maxDurationSecondsFor(AttachmentType type) {
    switch (type) {
      case AttachmentType.voice:
        return maxVoiceDurationSeconds;
      case AttachmentType.videoNote:
        return maxVideoNoteDurationSeconds;
      case AttachmentType.image:
      case AttachmentType.video:
      case AttachmentType.file:
        return null;
    }
  }

  /// Whether a frame of this size may be sent as a `video_note`.
  ///
  /// The rule lives here rather than in whatever is holding the camera, so
  /// the recorder picking a resolution and the check on the finished file
  /// cannot drift apart. Orientation does not matter — a portrait 480×720
  /// and a landscape 720×480 are the same frame turned sideways, and both
  /// are inside the cap.
  static bool fitsVideoNoteFrame(int width, int height) {
    if (width <= 0 || height <= 0) return false;

    final shortSide = width < height ? width : height;
    return shortSide <= maxVideoNoteResolutionPx;
  }

  /// The square a frame of this size becomes once the circle is cut out of
  /// it: the shorter side, never more than the cap.
  ///
  /// What the reader sees of a video note is the inscribed circle, so the
  /// square around that circle is the whole of the useful picture — the rest
  /// of a 4:3 frame is thrown away by every player on both sides of the
  /// wire. Sizing by it is what lets the capture be judged on the picture
  /// that survives rather than on the letterbox it arrived in.
  static int videoNoteSquareSide(int width, int height) {
    if (width <= 0 || height <= 0) return 0;

    final shortSide = width < height ? width : height;
    return shortSide < maxVideoNoteResolutionPx
        ? shortSide
        : maxVideoNoteResolutionPx;
  }

  static const Set<AttachmentType> exclusiveTypes = {
    AttachmentType.voice,
    AttachmentType.videoNote,
  };

  static bool isExclusive(AttachmentType type) => exclusiveTypes.contains(type);

  static bool requiresExplicitAttachmentType(AttachmentType type) =>
      isExclusive(type);

  static String? exclusivityViolation(Iterable<AttachmentType> types) {
    final all = types.toList();
    if (all.isEmpty) return null;

    final exclusive = all.where(isExclusive).toList();
    if (exclusive.isEmpty) return null;

    final distinctExclusive = exclusive.toSet();
    if (distinctExclusive.length > 1) {
      return 'A voice message and a video note can\'t be sent together — '
          'send them as separate messages';
    }

    final only = distinctExclusive.first;
    final label = only == AttachmentType.voice ? 'voice message' : 'video note';

    if (exclusive.length > 1) {
      return 'Only one $label can be sent per message '
          '(${exclusive.length} selected)';
    }

    if (all.length > exclusive.length) {
      return 'A $label can\'t be sent together with other attachments — '
          'send them as separate messages';
    }

    return null;
  }

  /// The MIME type the API expects for a file with this name.
  ///
  /// The server checks the type it is handed against the file's magic bytes
  /// (api-docs §5.5), so a wrong guess here is a rejected upload rather than
  /// a mislabelled file — hence a table of exactly what the documented
  /// buckets accept, and `application/octet-stream` for anything else, which
  /// is refused up front by [isAllowedMimeType].
  static String mimeFromName(String name) {
    final ext = name.split('.').last.toLowerCase();

    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'avi' => 'video/x-msvideo',
      'pdf' => 'application/pdf',
      'zip' => 'application/zip',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument'
            '.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument'
            '.spreadsheetml.sheet',
      _ => 'application/octet-stream',
    };
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
