import 'dart:typed_data';

/// Telling a rasteriser's antialiasing apart from a real change.
///
/// The same golden drawn on Linux and on Windows differs in 2–4 % of its
/// pixels: each platform hints and antialiases text its own way, so glyph
/// and icon edges spread their ink differently over the pixels they cross.
/// Pixel by pixel that looks like a lot; averaged over each pixel's 3×3
/// neighbourhood it all but cancels out, because the ink is the same and
/// only its split between neighbours differs.
///
/// A real change does not cancel out: a clock that reads "14:30" instead of
/// "2:30 PM", a face moved by a pixel, a colour swapped — each moves the
/// local average well past what antialiasing does.
///
/// Measured on the repo's goldens, Linux masters against Windows renders:
/// pure antialiasing leaves at most 0.12 % of pixels past the tolerance
/// below; a stale clock leaves 0.47 %, bubbles moved by 1 px at least 0.38 %.
abstract final class GoldenTolerance {
  /// How far a channel (0–255) of a pixel's 3×3 average may move.
  static const int blurredTolerance = 32;

  /// The share of pixels whose 3×3 average may move further than that.
  static const double changedThreshold = 0.0025;

  /// The share of pixels whose 3×3-averaged colour differs between [test]
  /// and [master] by more than [tolerance] in some channel.
  ///
  /// Both are tightly packed RGBA bytes of a [width] × [height] image. The
  /// averages are taken over the part of each neighbourhood inside the
  /// image, from one summed-area table of the difference per channel — the
  /// average of a difference is the difference of the averages.
  static double changedShare(
    Uint8List test,
    Uint8List master, {
    required int width,
    required int height,
    int tolerance = blurredTolerance,
  }) {
    assert(test.length == width * height * 4);
    assert(master.length == width * height * 4);

    final stride = width + 1;
    final tables = [
      for (var c = 0; c < 4; c++)
        _summedDifference(test, master, c, width, height),
    ];

    var changed = 0;
    for (var y = 0; y < height; y++) {
      final top = y == 0 ? 0 : y - 1;
      final bottom = y == height - 1 ? height : y + 2;
      for (var x = 0; x < width; x++) {
        final left = x == 0 ? 0 : x - 1;
        final right = x == width - 1 ? width : x + 2;
        final count = (bottom - top) * (right - left);

        for (final table in tables) {
          final sum =
              table[bottom * stride + right] -
              table[top * stride + right] -
              table[bottom * stride + left] +
              table[top * stride + left];
          if (sum.abs() > tolerance * count) {
            changed++;
            break;
          }
        }
      }
    }

    return changed / (width * height);
  }

  /// `table[y * (width + 1) + x]` is the sum of `test - master` in channel
  /// [channel] over every pixel above and left of (x, y).
  static Int32List _summedDifference(
    Uint8List test,
    Uint8List master,
    int channel,
    int width,
    int height,
  ) {
    final stride = width + 1;
    final table = Int32List(stride * (height + 1));
    for (var y = 0; y < height; y++) {
      var row = 0;
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4 + channel;
        row += test[i] - master[i];
        table[(y + 1) * stride + x + 1] = table[y * stride + x + 1] + row;
      }
    }
    return table;
  }
}
