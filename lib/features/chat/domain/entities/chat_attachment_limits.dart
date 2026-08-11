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
/// ⚠️ The buckets do **not** share limits, and the difference is not just the
/// size cap:
///
/// | bucket | max size | max per message | extra |
/// |---|---|---|---|
/// | image + video | 50 MB each | 10 | — |
/// | file | 100 MB | **1** | — |
/// | voice | 20 MB | **1** | ≤600 s, **exclusive** |
/// | video_note | 40 MB | **1** | ≤60 s, ≤640 px, **exclusive** |
///
/// A single message therefore cannot mix a document with photos, because the
/// document bucket allows exactly one attachment total.
///
/// ⚠️ **Exclusivity** (api-docs §6.5): `voice` and `video_note` do not share
/// the media/file counters at all — they may not travel with each other, nor
/// with any image/video/file, in one message. See
/// [exclusivityViolation], which is what enforces this before an upload is
/// spent; the backend's own `400 ATTACHMENT_LIMIT_EXCEEDED` is the final
/// authority.
abstract final class ChatAttachmentLimits {
  /// 50 MB — images and videos (api-docs §6.5).
  static const int maxMediaSizeBytes = 50 * 1024 * 1024;

  /// 100 MB — plain files (api-docs §6.5).
  static const int maxFileSizeBytes = 100 * 1024 * 1024;

  /// 20 MB — voice messages, `MAX_VOICE_SIZE` (api-docs §6.5).
  static const int maxVoiceSizeBytes = 20 * 1024 * 1024;

  /// 40 MB — video notes, `MAX_VIDEO_NOTE_SIZE` (api-docs §6.5).
  static const int maxVideoNoteSizeBytes = 40 * 1024 * 1024;

  /// Up to 10 images/videos per message.
  static const int maxMediaCount = 10;

  /// Exactly one document per message.
  static const int maxFileCount = 1;

  /// Exactly one voice message per message, and nothing else with it.
  static const int maxVoiceCount = 1;

  /// Exactly one video note per message, and nothing else with it.
  static const int maxVideoNoteCount = 1;

  /// 10 minutes — the longest voice message the backend accepts (api-docs
  /// §6.5).
  ///
  /// ⚠️ Duration is *not* known from a file's size or MIME, so unlike the size
  /// caps this cannot be checked in [ChatAttachmentLimits] alone: whatever
  /// records or picks the clip must measure it and reject it up front. It is
  /// declared here so there is a single source for that number when device
  /// recording lands (see the TODO in the composer).
  static const int maxVoiceDurationSeconds = 600;

  /// 60 seconds — the longest video note the backend accepts (api-docs §6.5).
  /// Same caveat as [maxVoiceDurationSeconds].
  static const int maxVideoNoteDurationSeconds = 60;

  /// 640 px — maximum width/height of a video note (api-docs §6.5). A video
  /// note is square, so this is the cap on both sides.
  static const int maxVideoNoteResolutionPx = 640;

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

  /// Voice-message MIME types (api-docs §6.5).
  ///
  /// ⚠️ Kept out of [allowedMimeTypes] deliberately: a voice message is
  /// exclusive, so it must never appear in the same picker allow-list as the
  /// media/file buckets — a user who could select an `.m4a` next to two photos
  /// would be assembling a message the backend is certain to reject.
  static const Set<String> voiceMimeTypes = {
    'audio/ogg',
    'audio/opus',
    'audio/mpeg',
    'audio/mp4',
    'audio/aac',
    'audio/webm',
    'audio/x-m4a',
  };

  /// Video-note MIME types (api-docs §6.5).
  ///
  /// ⚠️ A strict subset of [videoMimeTypes] — the *same* MIME can be either a
  /// plain video or a video note, which is exactly why `attachment_type` is
  /// mandatory for this type on the wire (see
  /// [requiresExplicitAttachmentType]): the backend cannot tell them apart
  /// from the MIME and would classify every video note as a plain video.
  static const Set<String> videoNoteMimeTypes = {
    'video/mp4',
    'video/webm',
    'video/quicktime',
  };

  /// Every MIME type the backend accepts for a **regular** (non-exclusive)
  /// attachment — hand this to `file_picker` as its allow-list so unsupported
  /// files can't be chosen at all.
  ///
  /// Voice/video-note MIME types are intentionally absent; see
  /// [voiceMimeTypes].
  static Set<String> get allowedMimeTypes => {
    ...imageMimeTypes,
    ...videoMimeTypes,
    ...fileMimeTypes,
  };

  /// File extensions matching [allowedMimeTypes], for pickers that filter by
  /// extension (`FilePicker.custom` + `allowedExtensions`) rather than MIME.
  static const List<String> allowedExtensions = [
    ...mediaExtensions,
    ...fileExtensions,
  ];

  /// Extensions of the image/video bucket only (≤50 MB, ≤10 per message).
  static const List<String> mediaExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'mp4',
    'mov',
    'webm',
  ];

  /// Extensions of the document bucket only (≤100 MB, **1** per message).
  ///
  /// Separate from [mediaExtensions] because the picker must be restricted to
  /// one bucket at a time: a message cannot mix the two (a document allows
  /// exactly one attachment in total), so a combined allow-list would let the
  /// user assemble a selection that is certain to be rejected.
  static const List<String> fileExtensions = [
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
    // ⚠️ Voice/video-note MIME types are not resolved here on purpose. Both
    // overlap with the buckets above (`video/mp4` is a plain video *and* a
    // video note; `audio/*` is nothing at all here), so the type cannot be
    // recovered from the MIME — it is a choice the caller makes when it
    // records the clip, and it must be carried explicitly all the way to
    // `attachment_type` (see [requiresExplicitAttachmentType]).
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
      case AttachmentType.voice:
        return maxVoiceSizeBytes;
      case AttachmentType.videoNote:
        return maxVideoNoteSizeBytes;
    }
  }

  /// Per-message count cap for [type]'s bucket.
  ///
  /// ⚠️ For [AttachmentType.voice] and [AttachmentType.videoNote] this is 1
  /// *and* nothing else may accompany it — a count alone cannot express that,
  /// so [exclusivityViolation] must be consulted as well.
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

  /// Longest allowed clip for [type], or `null` where duration is unbounded
  /// (api-docs §6.5).
  static int? maxDurationSecondsFor(AttachmentType type) {
    switch (type) {
      case AttachmentType.voice:
        return maxVoiceDurationSeconds;
      case AttachmentType.videoNote:
        return maxVideoNoteDurationSeconds;
      case AttachmentType.image:
      case AttachmentType.video:
      case AttachmentType.file:
        // The backend imposes no duration limit on a plain video (only a size
        // one), so there is nothing to check here.
        return null;
    }
  }

  /// The two types that may not be mixed with anything (api-docs §6.5).
  static const Set<AttachmentType> exclusiveTypes = {
    AttachmentType.voice,
    AttachmentType.videoNote,
  };

  static bool isExclusive(AttachmentType type) => exclusiveTypes.contains(type);

  /// Whether `attachment_type` **must** be sent explicitly in step 1 for
  /// [type] (api-docs §6.5).
  ///
  /// Only true for the exclusive types: the backend infers the type from the
  /// MIME when the field is omitted, and that inference can only ever produce
  /// `image`/`video`/`file` — an `audio/ogg` voice note would come back as a
  /// plain `file` and a `video/mp4` video note as a plain `video`, both
  /// silently, with the wrong limits applied and the wrong bubble rendered.
  static bool requiresExplicitAttachmentType(AttachmentType type) =>
      isExclusive(type);

  /// Checks the api-docs §6.5 exclusivity rule over a whole selection,
  /// returning a human-readable reason or `null` when the mix is legal.
  ///
  /// Split out from the count/size checks because it is not a per-file or even
  /// a per-bucket property: a lone voice message is fine, and a lone photo is
  /// fine, but the *combination* is not — so it can only be decided once the
  /// full selection is known.
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

  /// `12.4 MB` — for size-limit error messages and upload progress labels.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
