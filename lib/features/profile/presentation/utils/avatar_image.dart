import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:chatix/features/profile/domain/usecases/upload_avatar_use_case.dart';

/// A picture that is ready to be sent as an avatar.
class PreparedAvatar {
  const PreparedAvatar({
    required this.bytes,
    required this.contentType,
    required this.filename,
  });

  final Uint8List bytes;
  final String contentType;
  final String filename;
}

/// The picture could not be turned into an avatar on this device.
///
/// Distinct from anything the server says: this happens before a single
/// request, which is the whole point of doing the work here.
class AvatarPreparationException implements Exception {
  const AvatarPreparationException(this.reason);

  final AvatarPreparationFailure reason;
}

enum AvatarPreparationFailure {
  /// The bytes are not an image any platform decoder recognises.
  undecodable,

  /// Even re-encoded at the smallest size it is still over the 5 MB cap.
  tooLarge,
}

/// Cropping, resizing and re-encoding an avatar before it is uploaded.
///
/// Done on the client because the server cannot tell us when it is unhappy:
/// the size and MIME checks run in a background task whose complaints
/// (`AVATAR_SIZE`, `AVATAR_NOT_TYPE_IMAGE`) reach no HTTP response — a file
/// it rejects just silently never becomes an avatar (api-docs §2.5, §4.5).
/// Everything that can be checked or fixed here therefore is.
abstract final class AvatarImage {
  /// The largest variant the server generates is 512 px (api-docs §4.5), so
  /// this is already twice what any of them needs.
  static const int targetSize = 1024;

  /// What a picture is re-rendered at when the first encode came out too
  /// big — still the full size of the largest server-side variant.
  static const int fallbackSize = 512;

  /// PNG, because it is the one encoder `dart:ui` exposes. Lossless is fine
  /// at these dimensions, and the server re-encodes to jpg/webp/avif anyway.
  static const String contentType = 'image/png';

  /// Decodes [bytes], or throws [AvatarPreparationException] when nothing on
  /// this platform can read them.
  static Future<ui.Image> decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      throw const AvatarPreparationException(
        AvatarPreparationFailure.undecodable,
      );
    }
  }

  /// Renders [crop] out of [source] as a square PNG small enough to upload.
  ///
  /// [crop] is in [source]'s own pixels — the rect [avatarCropRect] hands
  /// back.
  static Future<PreparedAvatar> render({
    required ui.Image source,
    required ui.Rect crop,
    required String sourceFilename,
  }) async {
    var bytes = await _encode(source: source, crop: crop, side: targetSize);

    if (bytes.length > UploadAvatarUseCase.maxSizeBytes) {
      bytes = await _encode(source: source, crop: crop, side: fallbackSize);
    }

    if (bytes.length > UploadAvatarUseCase.maxSizeBytes) {
      throw const AvatarPreparationException(
        AvatarPreparationFailure.tooLarge,
      );
    }

    return PreparedAvatar(
      bytes: bytes,
      contentType: contentType,
      filename: pngFilename(sourceFilename),
    );
  }

  static Future<Uint8List> _encode({
    required ui.Image source,
    required ui.Rect crop,
    required int side,
  }) async {
    // Never upscale: a 200 px selfie blown up to 1024 is four times the
    // bytes and not one extra pixel of detail.
    final target = crop.width < side ? crop.width.round() : side;
    final edge = target < 1 ? 1 : target;

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      source,
      crop,
      ui.Rect.fromLTWH(0, 0, edge.toDouble(), edge.toDouble()),
      ui.Paint()
        ..isAntiAlias = true
        ..filterQuality = ui.FilterQuality.high,
    );

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(edge, edge);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw const AvatarPreparationException(
            AvatarPreparationFailure.undecodable,
          );
        }
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  /// [source] with a `.png` extension, since that is what now comes out of
  /// [render].
  ///
  /// The name is only ever part of an S3 key — the server sanitises it with
  /// `[^\w.\-]` → `_` and stores it at `{user_id}/{clean_filename}`
  /// (api-docs §4.5) — but handing it a name that matches the bytes keeps
  /// the bucket readable.
  static String pngFilename(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return 'avatar.png';

    final dot = trimmed.lastIndexOf('.');
    final stem = dot > 0 ? trimmed.substring(0, dot) : trimmed;
    return '$stem.png';
  }
}
