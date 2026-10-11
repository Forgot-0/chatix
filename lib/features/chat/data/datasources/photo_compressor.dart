import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueChanged, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/photo_compression.dart';

/// A photo ready to go: JPEG bytes and the size they describe.
class PreparedPhoto {
  const PreparedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Turns encoded photo bytes into the photo that is sent
/// ([PhotoCompression]): orientation baked in, long side capped, EXIF —
/// location included — gone, JPEG.
///
/// Pure and synchronous, so it can run in a background isolate. Null when
/// the bytes are not a still image the `image` package decodes — an
/// animated one included, which is better sent as it is.
PreparedPhoto? preparePhoto(
  Uint8List source, {
  int maxSide = PhotoCompression.maxSide,
  int quality = PhotoCompression.jpegQuality,
  ValueChanged<double>? onProgress,
}) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(source);
  } catch (_) {
    // Some decoders throw on a truncated file rather than answering null.
    return null;
  }
  if (decoded == null || decoded.numFrames > 1) return null;
  onProgress?.call(0.45);

  // The tag says which way is up; the pixels have to say it themselves once
  // the tag is gone.
  final upright = img.bakeOrientation(decoded);
  onProgress?.call(0.55);

  return _finish(
    upright,
    maxSide: maxSide,
    quality: quality,
    onProgress: onProgress,
  );
}

/// The same for pixels some other decoder produced — the platform's, for
/// HEIC — as `width` × `height` RGBA.
PreparedPhoto preparePixels(
  Uint8List rgba, {
  required int width,
  required int height,
  int maxSide = PhotoCompression.maxSide,
  int quality = PhotoCompression.jpegQuality,
  ValueChanged<double>? onProgress,
}) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  onProgress?.call(0.55);

  return _finish(
    image,
    maxSide: maxSide,
    quality: quality,
    onProgress: onProgress,
  );
}

PreparedPhoto _finish(
  img.Image source, {
  required int maxSide,
  required int quality,
  ValueChanged<double>? onProgress,
}) {
  var image = source;

  if (image.hasPalette) image = image.convert(numChannels: 4);

  final longSide = math.max(image.width, image.height);
  if (longSide > maxSide) {
    final landscape = image.width >= image.height;
    image = img.copyResize(
      image,
      width: landscape ? maxSide : null,
      height: landscape ? null : maxSide,
      interpolation: img.Interpolation.average,
    );
  }
  onProgress?.call(0.8);

  // JPEG has no transparency: what was see-through becomes white rather
  // than whatever colour happened to sit under the alpha.
  if (image.hasAlpha) {
    final ground = img.Image(width: image.width, height: image.height);
    img.fill(ground, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(ground, image);
    image = ground;
  }

  // Every EXIF field goes — the location first among them. The encoder
  // writes no EXIF block for an empty one.
  image.exif = img.ExifData();

  final bytes = img.encodeJpg(
    image,
    quality: quality,
    chroma: img.JpegChroma.yuv420,
  );
  onProgress?.call(1);

  return PreparedPhoto(bytes: bytes, width: image.width, height: image.height);
}

/// Prepares picked photos for sending, off the UI thread.
abstract interface class PhotoCompressor {
  /// The compressed stand-in for [upload], or null when it stays as it is —
  /// not a still photo, or one nothing on this device can decode.
  Future<AttachmentUploadRequestEntity?> compress(
    AttachmentUploadRequestEntity upload, {
    ValueChanged<double>? onProgress,
  });
}

/// Pixels from the platform's own image decoder — the only HEIC decoder
/// there is on iOS, macOS and Android 9+. Null where it cannot read them.
typedef PlatformPhotoDecoder =
    Future<({Uint8List rgba, int width, int height})?> Function(
      Uint8List bytes,
      int maxSide,
    );

/// [PhotoCompressor] that does the work in a background isolate, one photo
/// per isolate, and writes the result to a temporary file the upload then
/// streams from.
class IsolatePhotoCompressor implements PhotoCompressor {
  IsolatePhotoCompressor({
    Directory? outputDirectory,
    PlatformPhotoDecoder? platformDecoder,
  }) : _outputDirectory = outputDirectory,
       _platformDecoder = platformDecoder ?? decodeWithPlatform;

  final Directory? _outputDirectory;
  final PlatformPhotoDecoder _platformDecoder;

  static int _sequence = 0;

  @override
  Future<AttachmentUploadRequestEntity?> compress(
    AttachmentUploadRequestEntity upload, {
    ValueChanged<double>? onProgress,
  }) async {
    if (kIsWeb || !PhotoCompression.appliesTo(upload)) return null;

    try {
      final source = await _bytesOf(upload);
      if (source == null) return null;
      onProgress?.call(0.1);

      final output = await _outputFileFor(upload);
      var outcome = await _run(
        _Job(source: source, outputPath: output.path),
        onProgress,
      );

      if (outcome is _Undecodable &&
          PhotoCompression.platformDecodedMimeTypes.contains(
            upload.mimeType.toLowerCase(),
          )) {
        final pixels = await _platformDecoder(source, PhotoCompression.maxSide);
        if (pixels != null) {
          outcome = await _run(
            _Job(
              source: pixels.rgba,
              outputPath: output.path,
              width: pixels.width,
              height: pixels.height,
            ),
            onProgress,
          );
        }
      }

      if (outcome is! _Done) {
        if (outcome is _Failed) {
          Logger.warning(
            'Photo: ${upload.filename} kept as is (${outcome.why})',
          );
        }
        return null;
      }

      return AttachmentUploadRequestEntity(
        filename: PhotoCompression.jpegName(upload.filename),
        mimeType: PhotoCompression.outputMimeType,
        fileSize: outcome.size,
        filePath: output.path,
      );
    } catch (error) {
      Logger.warning('Photo: ${upload.filename} kept as is ($error)');
      return null;
    }
  }

  Future<Uint8List?> _bytesOf(AttachmentUploadRequestEntity upload) async {
    final bytes = upload.bytes;
    if (bytes != null) return Uint8List.fromList(bytes);

    final path = upload.filePath;
    if (path == null) return null;
    return File(path).readAsBytes();
  }

  Future<File> _outputFileFor(AttachmentUploadRequestEntity upload) async {
    final directory =
        _outputDirectory ??
        Directory('${Directory.systemTemp.path}/chatix_outgoing');
    await directory.create(recursive: true);

    final stamp = DateTime.now().microsecondsSinceEpoch;
    return File('${directory.path}/${stamp}_${_sequence++}.jpg');
  }

  /// One photo in its own isolate, reporting progress as it goes.
  Future<_Outcome> _run(_Job job, ValueChanged<double>? onProgress) async {
    final messages = ReceivePort();
    final errors = RawReceivePort();
    final done = Completer<_Outcome>();

    errors.handler = (Object? message) {
      if (!done.isCompleted) done.complete(_Failed('$message'));
    };

    messages.listen((message) {
      switch (message) {
        case final double progress:
          onProgress?.call(progress);
        case final _Outcome outcome:
          if (!done.isCompleted) done.complete(outcome);
      }
    });

    try {
      await Isolate.spawn(
        _compressInIsolate,
        job.withPort(messages.sendPort),
        onError: errors.sendPort,
        debugName: 'photo-compressor',
      );
      return await done.future;
    } finally {
      messages.close();
      errors.close();
    }
  }
}

/// Decodes [bytes] with the engine's codecs, which reach the platform's
/// decoders — the way HEIC is read. At most [maxSide] on the long side, so
/// a 50-megapixel photo is never held at full size.
Future<({Uint8List rgba, int width, int height})?> decodeWithPlatform(
  Uint8List bytes,
  int maxSide,
) async {
  ui.Codec? codec;
  ui.Image? image;
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);

      // One side only: the other follows the aspect, whichever way up the
      // decoder turns the picture.
      final landscape = descriptor.width >= descriptor.height;
      final longSide = math.max(descriptor.width, descriptor.height);
      final target = math.min(longSide, maxSide);
      codec = await descriptor.instantiateCodec(
        targetWidth: landscape ? target : null,
        targetHeight: landscape ? null : target,
      );
    } finally {
      // As the engine's own instantiateImageCodecWithSize does.
      buffer.dispose();
    }

    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;

    return (
      rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width: image.width,
      height: image.height,
    );
  } catch (error) {
    Logger.warning('Photo: the platform could not decode it either ($error)');
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}

class _Job {
  const _Job({
    required this.source,
    required this.outputPath,
    this.width,
    this.height,
    this.port,
  });

  /// Encoded photo bytes, or raw RGBA when [width] and [height] are set.
  final Uint8List source;
  final String outputPath;
  final int? width;
  final int? height;
  final SendPort? port;

  _Job withPort(SendPort port) => _Job(
    source: source,
    outputPath: outputPath,
    width: width,
    height: height,
    port: port,
  );
}

sealed class _Outcome {
  const _Outcome();
}

class _Done extends _Outcome {
  const _Done(this.size);

  final int size;
}

class _Undecodable extends _Outcome {
  const _Undecodable();
}

class _Failed extends _Outcome {
  const _Failed(this.why);

  final String why;
}

void _compressInIsolate(_Job job) {
  final port = job.port!;
  try {
    final width = job.width;
    final height = job.height;

    final prepared = width != null && height != null
        ? preparePixels(
            job.source,
            width: width,
            height: height,
            onProgress: port.send,
          )
        : preparePhoto(job.source, onProgress: port.send);

    if (prepared == null) {
      port.send(const _Undecodable());
      return;
    }

    File(job.outputPath).writeAsBytesSync(prepared.bytes, flush: true);
    port.send(_Done(prepared.bytes.length));
  } catch (error) {
    port.send(_Failed('$error'));
  }
}

final photoCompressorProvider = Provider<PhotoCompressor>(
  (ref) => IsolatePhotoCompressor(),
);
