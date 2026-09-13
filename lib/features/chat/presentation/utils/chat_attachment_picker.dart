import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';

/// Getting files out of the platform and into upload requests.
///
/// No UI of its own any more — the composer's attachment sheet is the menu,
/// and this is only the part that talks to the plugins. Media and documents
/// come from different ones and carry different limits (api-docs §5.5), so
/// each entry point is its own call.
abstract final class ChatAttachmentPicker {
  /// Photos and videos out of the system picker.
  ///
  /// The composer's own strip covers the last couple of dozen; this is how
  /// anything older is reached, and the only route at all on a platform with
  /// no readable gallery.
  static Future<List<AttachmentUploadRequestEntity>> pickMedia() async {
    final files = await ImagePicker().pickMultiImage(
      limit: ChatAttachmentLimits.maxMediaCount,
    );

    final uploads = <AttachmentUploadRequestEntity>[];
    for (final file in files) {
      uploads.add(
        AttachmentUploadRequestEntity(
          filename: file.name,
          mimeType: file.mimeType ?? mimeFromName(file.name),
          fileSize: await file.length(),
          filePath: file.path,
        ),
      );
    }
    return uploads;
  }

  /// One shot from the camera.
  static Future<List<AttachmentUploadRequestEntity>> takePhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    if (file == null) return const [];

    return [
      AttachmentUploadRequestEntity(
        filename: file.name,
        mimeType: file.mimeType ?? mimeFromName(file.name),
        fileSize: await file.length(),
        filePath: file.path,
      ),
    ];
  }

  static Future<List<AttachmentUploadRequestEntity>> pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ChatAttachmentLimits.fileExtensions,
      allowMultiple: false,
      withData: kIsWeb,
      withReadStream: false,
    );

    final picked = result?.files.singleOrNull;
    if (picked == null) return const [];

    return [
      AttachmentUploadRequestEntity(
        filename: picked.name,
        mimeType: mimeFromName(picked.name),
        fileSize: picked.size,
        filePath: kIsWeb ? null : picked.path,
        bytes: picked.bytes,
      ),
    ];
  }

  /// Reads a local video's duration and frame size, or null if it will not
  /// open. Exposed so the video-note rules can be checked without a camera.
  static Future<VideoProbe?> probeVideo(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      final value = controller.value;

      return VideoProbe(
        duration: value.duration,
        width: value.size.width.round(),
        height: value.size.height.round(),
      );
    } catch (error) {
      Logger.warning('Video note: could not be read ($error)');
      return null;
    } finally {
      await controller.dispose();
    }
  }

  /// The MIME type for a picked file, by name.
  ///
  /// Kept as a pass-through so the pickers do not have to reach into the
  /// limits entity, and so there is one table rather than two.
  static String mimeFromName(String name) =>
      ChatAttachmentLimits.mimeFromName(name);
}

class VideoProbe {
  const VideoProbe({
    required this.duration,
    required this.width,
    required this.height,
  });

  final Duration duration;
  final int width;
  final int height;
}
