import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';

/// One photo or video out of the device gallery, as the attachment strip
/// needs it: something to draw now, and a file to read only if it is picked.
class RecentMediaItem {
  const RecentMediaItem({
    required this.id,
    required this.isVideo,
    required this.duration,
  });

  final String id;
  final bool isVideo;

  /// Zero for stills.
  final Duration duration;
}

/// How far the gallery is open to us.
enum RecentMediaAccess {
  /// Not asked yet — the state the sheet opens in.
  unknown,

  /// The platform has no gallery to read, or the plugin is not there.
  unsupported,

  /// Asked and refused.
  denied,

  /// Everything, or the subset the reader picked on iOS/Android 14's
  /// "limited" grant — either way there is something to show.
  granted,
}

/// Reads the newest items out of the device gallery.
///
/// The attachment sheet shows them inline instead of handing off to the
/// system picker, which is the whole point of having our own sheet. Behind
/// an interface because the only implementation talks to a plugin that has
/// nothing to say in a test.
abstract interface class RecentMediaSource {
  /// Whether the gallery can be read, asking for the grant if it has not
  /// been asked for yet.
  Future<RecentMediaAccess> access();

  /// The newest [limit] items, newest first. Empty when there is no access.
  Future<List<RecentMediaItem>> recent({int limit});

  /// A square thumbnail, or null if it cannot be produced.
  Future<Uint8List?> thumbnail(String id, {int size});

  /// Turns a picked item into something the uploader can take.
  ///
  /// Null when the file has gone (a photo deleted between the strip being
  /// drawn and it being tapped) or its type is not one the API accepts.
  Future<AttachmentUploadRequestEntity?> upload(String id);
}

class PhotoManagerRecentMediaSource implements RecentMediaSource {
  const PhotoManagerRecentMediaSource();

  /// Android and iOS only. `photo_manager` builds on desktop but has no
  /// library to read there, and the strip is simply absent.
  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<RecentMediaAccess> access() async {
    if (!isSupportedPlatform) return RecentMediaAccess.unsupported;

    try {
      final state = await PhotoManager.requestPermissionExtend();
      return switch (state) {
        // "limited" is a real grant over a subset the reader chose; showing
        // that subset is right, and nagging for more is not ours to do.
        PermissionState.authorized ||
        PermissionState.limited => RecentMediaAccess.granted,
        _ => RecentMediaAccess.denied,
      };
    } catch (error) {
      Logger.warning('Recent media: permission check failed ($error)');
      return RecentMediaAccess.unsupported;
    }
  }

  @override
  Future<List<RecentMediaItem>> recent({int limit = 24}) async {
    if (limit <= 0) return const [];

    try {
      final assets = await PhotoManager.getAssetListRange(
        start: 0,
        end: limit,
        type: RequestType.common,
      );

      return [
        for (final asset in assets)
          RecentMediaItem(
            id: asset.id,
            isVideo: asset.type == AssetType.video,
            duration: asset.type == AssetType.video
                ? asset.videoDuration
                : Duration.zero,
          ),
      ];
    } catch (error) {
      Logger.warning('Recent media: listing failed ($error)');
      return const [];
    }
  }

  @override
  Future<Uint8List?> thumbnail(String id, {int size = 256}) async {
    try {
      final asset = await AssetEntity.fromId(id);
      if (asset == null) return null;

      return await asset.thumbnailDataWithSize(ThumbnailSize.square(size));
    } catch (error) {
      Logger.warning('Recent media: thumbnail failed ($error)');
      return null;
    }
  }

  @override
  Future<AttachmentUploadRequestEntity?> upload(String id) async {
    try {
      final asset = await AssetEntity.fromId(id);
      if (asset == null) return null;

      final file = await asset.file;
      if (file == null) return null;

      final name = asset.title ?? file.path.split('/').last;

      // The server checks the MIME it is handed against the file's magic
      // bytes, so a guess from the name is safer than nothing but worse than
      // what the gallery itself recorded.
      final mimeType =
          await asset.mimeTypeAsync ?? ChatAttachmentLimits.mimeFromName(name);

      return AttachmentUploadRequestEntity(
        filename: name,
        mimeType: mimeType,
        fileSize: await file.length(),
        filePath: file.path,
      );
    } catch (error) {
      Logger.warning('Recent media: resolving $id failed ($error)');
      return null;
    }
  }
}

/// Nothing to show — what every platform without a gallery gets, and what a
/// test gets unless it says otherwise.
class EmptyRecentMediaSource implements RecentMediaSource {
  const EmptyRecentMediaSource();

  @override
  Future<RecentMediaAccess> access() async => RecentMediaAccess.unsupported;

  @override
  Future<List<RecentMediaItem>> recent({int limit = 24}) async => const [];

  @override
  Future<Uint8List?> thumbnail(String id, {int size = 256}) async => null;

  @override
  Future<AttachmentUploadRequestEntity?> upload(String id) async => null;
}

final recentMediaSourceProvider = Provider<RecentMediaSource>((ref) {
  return PhotoManagerRecentMediaSource.isSupportedPlatform
      ? const PhotoManagerRecentMediaSource()
      : const EmptyRecentMediaSource();
});
