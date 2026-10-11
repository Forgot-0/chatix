import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';

/// A video's poster: the first frame, made on this device.
///
/// The API keeps no poster and no thumbnail of any kind — an attachment is
/// its `s3_key` and nothing else (api-docs §5.5) — so a video in the feed
/// has no picture until one is taken from the file itself. That happens in
/// two places: once the file has come down into the cache, and, for a video
/// of our own, before it is uploaded at all.
///
/// Posters live in the attachment cache beside the files they were taken
/// from, named by the same key, so they are found without the presigned
/// link (which is dead in 300 seconds) and evicted by the same budget.
abstract final class VideoPoster {
  /// How wide a poster is made. A feed tile is at most 420 px across
  /// (`ChatLayout.mediaMaxWidthWide`), and the viewer only shows the poster
  /// until the video's own first frame replaces it.
  static const int maxWidth = 720;

  /// JPEG quality: a still that is about to be replaced does not need more.
  static const int quality = 80;

  /// The biggest video fetched ahead just so its tile can have a picture.
  ///
  /// Only when the reader's auto-download setting allows videos on this
  /// connection at all; past this size a poster is not worth the bytes, and
  /// the tile waits for the video to be opened.
  static const int prefetchMaxBytes = 16 * 1024 * 1024;

  /// Whether [attachment] is small enough to be fetched for its poster.
  static bool isWorthPrefetching(AttachmentEntity attachment) =>
      attachment.size > 0 && attachment.size <= prefetchMaxBytes;

  /// Whether a staged upload is a video that gets a poster before it goes
  /// out. Video notes do not: they are drawn round, from their own player.
  static bool isFor(AttachmentUploadRequestEntity upload) =>
      upload.resolvedType == AttachmentType.video && upload.filePath != null;

  /// The key a downloaded video's poster is filed under: its `s3_key`, the
  /// one thing about the object that never changes.
  static String keyOf(AttachmentEntity attachment) => attachment.s3Key;

  /// The key a poster made from a file on this device is filed under, until
  /// it is known where that file went.
  static String localKey(String path) => 'local:$path';

  /// The key a poster is filed under once its file has an upload slot.
  ///
  /// The slot's token is the id the attachment will have (api-docs §5.5),
  /// while its `s3_key` is not known until the message comes back — so the
  /// poster waits under the token and moves under the key the first time
  /// the attachment is seen.
  static String uploadKey(String uploadToken) => 'upload:$uploadToken';
}
