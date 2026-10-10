import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// The launcher icons and splash images are rendered from the logo's painter
/// by tool/brand/export_brand_assets_test.dart, then handed to
/// flutter_launcher_icons and flutter_native_splash. These checks hold the
/// PNGs to what each platform does with them, and the generators' colours to
/// the tokens they were copied from.
class _Png {
  _Png(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final ByteData rgba;

  int alphaAt(double x, double y) =>
      rgba.getUint8((y.round() * width + x.round()) * 4 + 3);

  /// Whether anything at all is drawn on a circle of [radius] around the
  /// centre.
  bool paintsOnCircle(double radius) {
    for (var step = 0; step < 720; step++) {
      final angle = step * math.pi / 360;
      final x = width / 2 + radius * math.cos(angle);
      final y = height / 2 + radius * math.sin(angle);
      if (x < 0 || y < 0 || x > width - 1 || y > height - 1) continue;
      if (alphaAt(x, y) != 0) return true;
    }
    return false;
  }
}

Future<_Png> _load(WidgetTester tester, String path) async {
  final png = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    final image = (await codec.getNextFrame()).image;
    final bytes = await image.toByteData();
    final result = _Png(image.width, image.height, bytes!);
    image.dispose();
    codec.dispose();
    return result;
  });
  return png!;
}

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  testWidgets('the store icon is a full, opaque square', (tester) async {
    final icon = await _load(tester, 'assets/icon/app_icon.png');

    expect((icon.width, icon.height), (1024, 1024));
    // iOS masks it itself and refuses transparency.
    for (final (x, y) in [
      (0.0, 0.0),
      (1023.0, 0.0),
      (0.0, 1023.0),
      (1023.0, 1023.0),
    ]) {
      expect(icon.alphaAt(x, y), 255);
    }
  });

  for (final layer in [
    'assets/icon/app_icon_foreground.png',
    'assets/icon/app_icon_monochrome.png',
  ]) {
    testWidgets('$layer stays inside the adaptive icon safe zone', (
      tester,
    ) async {
      final png = await _load(tester, layer);

      expect((png.width, png.height), (1024, 1024));
      // A launcher may show no more than the middle 66 of the 108 dp.
      final safeRadius = 1024 * 33 / 108;
      expect(png.paintsOnCircle(safeRadius + 2), isFalse);
      expect(png.paintsOnCircle(safeRadius * 0.6), isTrue);
    });
  }

  testWidgets('the desktop icon is the bubble alone', (tester) async {
    final mark = await _load(tester, 'assets/icon/app_icon_mark.png');

    expect((mark.width, mark.height), (1024, 1024));
    expect(mark.alphaAt(0, 0), 0);
    expect(mark.alphaAt(512, 512), 255);
  });

  testWidgets('the Android 12 splash icon survives its circular mask', (
    tester,
  ) async {
    final splash = await _load(
      tester,
      'assets/splash/splash_logo_android12.png',
    );

    expect((splash.width, splash.height), (1152, 1152));
    expect(splash.paintsOnCircle(768 / 2 + 2), isFalse);
  });

  testWidgets('the launch screen logo is the welcome logo at 4x', (
    tester,
  ) async {
    final splash = await _load(tester, 'assets/splash/splash_logo.png');

    expect(splash.width, (AppBrandMark.welcomeSize * 4).round());
    expect(splash.height, splash.width);
  });

  group('generator colours match the tokens', () {
    test('adaptive icon background', () {
      expect(
        File('flutter_launcher_icons.yaml').readAsStringSync(),
        contains('adaptive_icon_background: "${_hex(AppNeutrals.light[0])}"'),
      );
      expect(
        File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
        contains('>${_hex(AppNeutrals.light[0])}<'),
      );
    });

    test('launch screens use each theme\'s canvas', () {
      final config = File('flutter_native_splash.yaml').readAsStringSync();
      final light = _hex(AppNeutrals.canvas(Brightness.light));
      final dark = _hex(AppNeutrals.canvas(Brightness.dark));

      expect(RegExp('color: "$light"').allMatches(config), hasLength(2));
      expect(RegExp('color_dark: "$dark"').allMatches(config), hasLength(2));
      expect(
        File(
          'android/app/src/main/res/values-night-v31/styles.xml',
        ).readAsStringSync(),
        contains(
          '<item name="android:windowSplashScreenBackground">$dark</item>',
        ),
      );
    });

    test('web manifest', () {
      final manifest =
          jsonDecode(File('web/manifest.json').readAsStringSync())
              as Map<String, Object?>;
      expect(manifest['theme_color'], _hex(AppPalette.violet));
      expect(
        manifest['background_color'],
        _hex(AppNeutrals.canvas(Brightness.light)),
      );
    });
  });
}
