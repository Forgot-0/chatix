import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'helpers/golden_tolerance.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();

  if (goldenFileComparator is LocalFileComparator) {
    final testUrl = (goldenFileComparator as LocalFileComparator).basedir;
    goldenFileComparator = AntialiasingTolerantComparator(
      Uri.parse('$testUrl/test.dart'),
    );
  }

  return testMain();
}

/// Passes a golden that differs from its master only by antialiasing.
///
/// Goldens are drawn on whatever machine regenerated them — a developer's
/// Windows box, the Linux CI runner — and each platform's rasteriser draws
/// text edges its own way, which alone moves 2–4 % of a text-heavy golden's
/// pixels. A flat "up to N % may differ" cannot tell that from a real change
/// of the same size: it once let a bubble clock reading "14:30" pass against
/// one reading "2:30 PM". So the comparison is made after averaging each
/// pixel with its neighbours, where antialiasing cancels out and a change
/// does not ([GoldenTolerance]).
class AntialiasingTolerantComparator extends LocalFileComparator {
  AntialiasingTolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = Uint8List.fromList(await getGoldenBytes(golden));
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      goldenBytes,
    );

    try {
      if (result.passed) return true;

      final changed = await _changedShare(imageBytes, goldenBytes);
      if (changed != null && changed <= GoldenTolerance.changedThreshold) {
        debugPrint(
          'Golden "${golden.path}" differs by '
          '${_percent(result.diffPercent)} pixel for pixel, '
          '${_percent(changed)} once antialiasing is averaged out. Passing.',
        );
        return true;
      }

      final error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(
        changed == null
            ? error
            : '$error\n${_percent(changed)} of pixels differ once '
                  'antialiasing is averaged out; '
                  '${_percent(GoldenTolerance.changedThreshold)} may.',
      );
    } finally {
      result.dispose();
    }
  }

  /// Null when the two cannot be compared pixel for pixel — a different
  /// size, which the failure output already explains.
  static Future<double?> _changedShare(Uint8List test, Uint8List master) async {
    final a = await _decode(test);
    final b = await _decode(master);
    try {
      if (a.width != b.width || a.height != b.height) return null;

      final testPixels = await a.toByteData(format: ui.ImageByteFormat.rawRgba);
      final masterPixels = await b.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (testPixels == null || masterPixels == null) return null;

      return GoldenTolerance.changedShare(
        testPixels.buffer.asUint8List(),
        masterPixels.buffer.asUint8List(),
        width: a.width,
        height: a.height,
      );
    } finally {
      a.dispose();
      b.dispose();
    }
  }

  static Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  static String _percent(double share) =>
      '${(share * 100).toStringAsFixed(2)}%';
}
