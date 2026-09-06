import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:chatix/core/images/image_processor.dart';

class DebugImageProcessor implements ImageProcessor {
  @override
  Future<Uint8List> resize({
    required Uint8List imageData,
    required int width,
    required int height,
    bool maintainAspectRatio = true,
  }) async {
    debugPrint(
      '🖼️ Resizing image to $width x $height (maintainAspectRatio: $maintainAspectRatio)',
    );
    await Future.delayed(const Duration(milliseconds: 300));
    return imageData;
  }

  @override
  Future<Uint8List> compress({
    required Uint8List imageData,
    required int quality,
  }) async {
    debugPrint('🖼️ Compressing image with quality: $quality');
    await Future.delayed(const Duration(milliseconds: 200));
    return imageData;
  }

  @override
  Future<Uint8List> crop({
    required Uint8List imageData,
    required Rect cropRect,
  }) async {
    debugPrint('🖼️ Cropping image with rect: $cropRect');
    await Future.delayed(const Duration(milliseconds: 150));
    return imageData;
  }

  @override
  Future<Uint8List> applyBlur({
    required Uint8List imageData,
    required double sigma,
  }) async {
    debugPrint('🖼️ Applying blur with sigma: $sigma');
    await Future.delayed(const Duration(milliseconds: 250));
    return imageData;
  }

  @override
  Future<Uint8List> toGrayscale({required Uint8List imageData}) async {
    debugPrint('🖼️ Converting image to grayscale');
    await Future.delayed(const Duration(milliseconds: 200));
    return imageData;
  }

  @override
  Future<Size> getImageDimensions(Uint8List imageData) async {
    debugPrint('🖼️ Getting image dimensions');
    await Future.delayed(const Duration(milliseconds: 50));
    return const Size(800, 600);
  }

  @override
  Future<Uint8List> convertFormat({
    required Uint8List imageData,
    required ImageFormat format,
    int quality = 95,
  }) async {
    debugPrint(
      '🖼️ Converting image to ${format.name} format with quality: $quality',
    );
    await Future.delayed(const Duration(milliseconds: 300));
    return imageData;
  }

  @override
  Future<Uint8List> generateThumbnail({
    required Uint8List imageData,
    required int maxDimension,
    int quality = 80,
  }) async {
    debugPrint(
      '🖼️ Generating thumbnail with max dimension: $maxDimension, quality: $quality',
    );
    await Future.delayed(const Duration(milliseconds: 200));
    return imageData;
  }
}
