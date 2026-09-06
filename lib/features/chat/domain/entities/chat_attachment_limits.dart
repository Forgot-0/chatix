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

  static const int maxVideoNoteDurationSeconds = 60;

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
    final label = only == AttachmentType.voice
        ? 'voice message'
        : 'video note';

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

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
