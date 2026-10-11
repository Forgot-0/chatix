import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';

/// How a photo is prepared for sending when nobody asks otherwise.
///
/// A phone photo is 12–50 megapixels and 3–15 MB, carries the place it was
/// taken in its EXIF, and is often stored sideways with a tag saying which
/// way is up. None of that is what a chat needs: 2560 px on the long side is
/// sharp on any screen the message will be opened on, JPEG at 85 % is where
/// the artefacts stop being visible, the orientation is turned into the
/// pixels so nothing downstream has to read a tag, and the location goes.
abstract final class PhotoCompression {
  static const int maxSide = 2560;

  static const int jpegQuality = 85;

  static const String outputMimeType = 'image/jpeg';

  /// What can be recompressed: still photos. A GIF keeps its animation by
  /// being left alone, and video is not a photo.
  static const Set<String> sourceMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  /// Formats only the platform's own decoder reads — there is no HEIF
  /// decoder in pure Dart.
  static const Set<String> platformDecodedMimeTypes = {
    'image/heic',
    'image/heif',
  };

  static bool appliesTo(AttachmentUploadRequestEntity upload) =>
      upload.attachmentType == null &&
      sourceMimeTypes.contains(upload.mimeType.toLowerCase());

  /// [filename] with a `.jpg` extension, which is what comes out.
  static String jpegName(String filename) {
    final trimmed = filename.trim();
    if (trimmed.isEmpty) return 'photo.jpg';

    final dot = trimmed.lastIndexOf('.');
    final stem = dot > 0 ? trimmed.substring(0, dot) : trimmed;
    return '$stem.jpg';
  }
}
