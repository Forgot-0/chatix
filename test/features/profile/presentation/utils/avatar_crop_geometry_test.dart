import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/profile/presentation/utils/avatar_crop_geometry.dart';

void main() {
  group('avatarFitScale', () {
    test('a landscape picture is scaled by its height', () {
      expect(
        avatarFitScale(imageSize: const Size(400, 200), viewportSide: 100),
        0.5,
      );
    });

    test('a portrait picture is scaled by its width', () {
      expect(
        avatarFitScale(imageSize: const Size(200, 400), viewportSide: 100),
        0.5,
      );
    });

    test('a picture smaller than the window is scaled up to cover it', () {
      expect(
        avatarFitScale(imageSize: const Size(50, 50), viewportSide: 100),
        2,
      );
    });
  });

  group('avatarCropRect', () {
    test('an untouched square picture crops to the whole of it', () {
      const image = Size(400, 400);
      final fit = avatarFitScale(imageSize: image, viewportSide: 200);

      expect(
        avatarCropRect(
          imageSize: image,
          viewportSide: 200,
          fitScale: fit,
          zoom: 1,
          translation: Offset.zero,
        ),
        const Rect.fromLTWH(0, 0, 400, 400),
      );
    });

    test('a centred landscape picture crops to its middle square', () {
      const image = Size(800, 400);
      const viewport = 200.0;
      final fit = avatarFitScale(imageSize: image, viewportSide: viewport);

      // Laid out at 400x200 and centred, so it sits 100 logical pixels left.
      final rect = avatarCropRect(
        imageSize: image,
        viewportSide: viewport,
        fitScale: fit,
        zoom: 1,
        translation: const Offset(-100, 0),
      );

      expect(rect, const Rect.fromLTWH(200, 0, 400, 400));
    });

    test('zooming in takes a smaller square out of the picture', () {
      const image = Size(400, 400);
      const viewport = 200.0;
      final fit = avatarFitScale(imageSize: image, viewportSide: viewport);

      final rect = avatarCropRect(
        imageSize: image,
        viewportSide: viewport,
        fitScale: fit,
        zoom: 2,
        translation: Offset.zero,
      );

      expect(rect, const Rect.fromLTWH(0, 0, 200, 200));
    });

    test('a rect that would run off the bitmap is pulled back on', () {
      const image = Size(400, 400);
      const viewport = 200.0;
      final fit = avatarFitScale(imageSize: image, viewportSide: viewport);

      final rect = avatarCropRect(
        imageSize: image,
        viewportSide: viewport,
        fitScale: fit,
        zoom: 2,
        // Far past anything the cropper's own bounds would allow.
        translation: const Offset(-1000, -1000),
      );

      expect(rect.right, lessThanOrEqualTo(image.width));
      expect(rect.bottom, lessThanOrEqualTo(image.height));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.width, 200);
    });

    test('a zero-sized picture crops to nothing rather than dividing by it', () {
      expect(
        avatarCropRect(
          imageSize: Size.zero,
          viewportSide: 200,
          fitScale: 1,
          zoom: 1,
          translation: Offset.zero,
        ),
        Rect.zero,
      );
    });

    test('the crop is always square', () {
      const image = Size(1000, 300);
      const viewport = 200.0;
      final fit = avatarFitScale(imageSize: image, viewportSide: viewport);

      final rect = avatarCropRect(
        imageSize: image,
        viewportSide: viewport,
        fitScale: fit,
        zoom: 1.4,
        translation: const Offset(-250, -12),
      );

      expect(rect.width, closeTo(rect.height, 0.0001));
    });
  });
}
