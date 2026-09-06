import 'dart:typed_data';
import 'package:flutter/foundation.dart';

abstract class ImageProcessor {
  Future<Uint8List> resize({
    required Uint8List imageData,
    required int width,
    required int height,
    bool maintainAspectRatio = true,
  });

  Future<Uint8List> compress({
    required Uint8List imageData,
    required int quality,
  });

  Future<Uint8List> crop({
    required Uint8List imageData,
    required Rect cropRect,
  });

  Future<Uint8List> applyBlur({
    required Uint8List imageData,
    required double sigma,
  });

  Future<Uint8List> toGrayscale({required Uint8List imageData});

  Future<Size> getImageDimensions(Uint8List imageData);

  Future<Uint8List> convertFormat({
    required Uint8List imageData,
    required ImageFormat format,
    int quality = 95,
  });

  Future<Uint8List> generateThumbnail({
    required Uint8List imageData,
    required int maxDimension,
    int quality = 80,
  });
}

enum ImageFormat { jpeg, png, webp }

class Size {
  final int width;
  final int height;

  const Size(this.width, this.height);

  @override
  String toString() => 'Size($width x $height)';
}

class Rect {
  final int x;
  final int y;
  final int width;
  final int height;

  const Rect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  String toString() => 'Rect(x: $x, y: $y, width: $width, height: $height)';
}
