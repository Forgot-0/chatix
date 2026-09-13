import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/utils/chat_attachment_picker.dart';

/// A picked file, named by what the layout needs to know about it.
typedef LocalMediaKey = ({String? path, bool isVideo});

/// The shape of a file that has not been uploaded yet.
///
/// The server fills `width`/`height` in only once it has validated the
/// upload (api-docs §5.5), so before that the album has to measure the file
/// itself — otherwise everything picked would be laid out as a square and
/// then jump into shape after sending.
///
/// Images are read through `ImageDescriptor`, which parses the header and
/// stops; nothing is decoded. Videos go through the same probe the video
/// note recorder uses.
final localMediaRatioProvider = FutureProvider.autoDispose
    .family<double?, LocalMediaKey>((ref, key) async {
      final path = key.path;
      if (path == null) return null;

      if (key.isVideo) {
        final probe = await ChatAttachmentPicker.probeVideo(path);
        if (probe == null || probe.height <= 0) return null;
        return probe.width / probe.height;
      }

      return imageRatioOfFile(path);
    });

/// Width ÷ height of the image at [path], or null when it cannot be read.
Future<double?> imageRatioOfFile(String path) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;

  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);

    final width = descriptor.width;
    final height = descriptor.height;
    if (width <= 0 || height <= 0) return null;

    return width / height;
  } catch (error) {
    Logger.warning('Album preview: could not measure $path ($error)');
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// Width ÷ height for [bytes], for the platforms that hand over the file
/// itself rather than a path.
Future<double?> imageRatioOfBytes(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;

  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);

    final width = descriptor.width;
    final height = descriptor.height;
    if (width <= 0 || height <= 0) return null;

    return width / height;
  } catch (error) {
    Logger.warning('Album preview: could not measure ${bytes.length} bytes '
        '($error)');
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// The key for [localMediaRatioProvider] for one staged upload.
LocalMediaKey localMediaKey(AttachmentUploadRequestEntity upload) => (
  path: upload.filePath,
  isVideo: ChatAttachmentLimits.typeOf(upload.mimeType) == AttachmentType.video,
);
