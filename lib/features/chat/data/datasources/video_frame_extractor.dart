import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:chatix/core/utils/logger.dart';

/// Takes a still out of a video file on this device.
///
/// A seam over the platform: there is no pure-Dart way to decode video, and
/// tests stand in for the plugin here rather than faking a method channel.
abstract class VideoFrameExtractor {
  /// The first frame of the video at [path] as a JPEG no wider than
  /// [maxWidth], or null when this platform cannot take one or the file has
  /// none to give. Never throws.
  Future<Uint8List?> firstFrame(
    String path, {
    required int maxWidth,
    required int quality,
  });
}

/// [VideoFrameExtractor] on `video_thumbnail`: MediaMetadataRetriever on
/// Android, AVAssetImageGenerator on iOS.
///
/// The plugin has nothing for desktops or the web, so there the answer is
/// always null and a video keeps its plain dark tile — the same as before
/// posters existed.
class PluginVideoFrameExtractor implements VideoFrameExtractor {
  const PluginVideoFrameExtractor();

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<Uint8List?> firstFrame(
    String path, {
    required int maxWidth,
    required int quality,
  }) async {
    if (!isSupported) return null;

    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxWidth,
        quality: quality,
      );
      return bytes == null || bytes.isEmpty ? null : bytes;
    } on PlatformException catch (error) {
      Logger.warning('Video poster: no frame from $path (${error.message})');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

final videoFrameExtractorProvider = Provider<VideoFrameExtractor>(
  (ref) => const PluginVideoFrameExtractor(),
);
