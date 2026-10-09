import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'golden_tolerance.dart';

/// What the golden comparator forgives across platforms, and what it still
/// catches.
void main() {
  const size = 20;

  /// A [size]² image with [paint] deciding the grey level per pixel.
  Uint8List image(int Function(int x, int y) paint) {
    final bytes = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final i = (y * size + x) * 4;
        final grey = paint(x, y);
        bytes
          ..[i] = grey
          ..[i + 1] = grey
          ..[i + 2] = grey
          ..[i + 3] = 255;
      }
    }
    return bytes;
  }

  double share(Uint8List test, Uint8List master) =>
      GoldenTolerance.changedShare(test, master, width: size, height: size);

  final blank = image((_, _) => 255);

  test('identical images have nothing to explain', () {
    expect(share(blank, blank), 0);
  });

  group('forgives antialiasing', () {
    test('the same ink spread differently across an edge', () {
      // One rasteriser covers the stem's pixel fully and half its
      // neighbour; the other covers both at three quarters.
      final master = image(
        (x, _) => switch (x) {
          10 => 0,
          11 => 128,
          _ => 255,
        },
      );
      final test = image((x, _) => x == 10 || x == 11 ? 64 : 255);

      expect(share(test, master), 0);
    });

    test('an edge pixel a shade lighter or darker', () {
      final master = image((x, _) => x == 10 ? 128 : 255);
      final test = image((x, _) => x == 10 ? 64 : 255);

      expect(share(test, master), 0);
    });
  });

  group('still catches', () {
    test('a sharp edge moved by a whole pixel', () {
      final master = image((x, _) => x == 10 ? 0 : 255);
      final test = image((x, _) => x == 11 ? 0 : 255);

      expect(
        share(test, master),
        greaterThan(GoldenTolerance.changedThreshold),
      );
    });

    test('a glyph that is not the same glyph', () {
      // A vertical stroke where there was a horizontal one: about as much
      // ink, in a different place.
      final master = image((x, y) => y == 10 && x >= 7 && x < 13 ? 0 : 255);
      final test = image((x, y) => x == 10 && y >= 7 && y < 13 ? 0 : 255);

      expect(
        share(test, master),
        greaterThan(GoldenTolerance.changedThreshold),
      );
    });

    test('an element that was not there', () {
      final test = image(
        (x, y) => x >= 5 && x < 15 && y >= 5 && y < 15 ? 0 : 255,
      );

      expect(share(test, blank), greaterThan(0.25));
    });

    test('an element that is gone', () {
      final master = image(
        (x, y) => x >= 5 && x < 15 && y >= 5 && y < 15 ? 0 : 255,
      );

      expect(share(blank, master), greaterThan(0.25));
    });

    test('a colour that changed', () {
      final master = image((_, _) => 40);
      final test = image((_, _) => 200);

      expect(share(test, master), 1);
    });
  });
}
