import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/brand/chatix_logo.dart';

/// Renders the launcher icons and splash images from [ChatixMarkPainter], so
/// the icon on the home screen is the logo on the sign-in screen, not a
/// redrawing of it.
///
/// Not part of the suite: it lives outside test/ and writes into the repo.
/// After changing the mark, run from the project root:
///
///     flutter test tool/brand/export_brand_assets_test.dart
///     dart run flutter_launcher_icons
///     dart run flutter_native_splash:create
void main() {
  testWidgets('exports the brand assets', (tester) async {
    await tester.runAsync(() async {
      for (final asset in brandAssets) {
        await asset.write();
      }
    });
  });
}

/// Android's adaptive icon is a 108 dp square of which a launcher may show
/// as little as a 66 dp circle; everything that matters has to fit inside it.
const double _adaptiveSafeShare = 66 / 108;

/// The largest mark side whose corners stay inside a circle [diameter] wide.
///
/// The farthest point of the bubble from its centre is on the anchor corner,
/// the tightest one: half the diagonal less what that corner's rounding
/// takes off it.
double _sideWithin(double diameter) =>
    diameter / (2 * (0.7071 - AppBrandMark.anchorRadius * 0.4142));

final List<BrandAsset> brandAssets = [
  // iOS, legacy Android and the web: full bleed, the system rounds it.
  BrandAsset(
    'assets/icon/app_icon.png',
    size: 1024,
    markShare: 0.62,
    background: AppNeutrals.light[0],
  ),
  // Android adaptive layers. The background is a flat colour set in
  // flutter_launcher_icons.yaml.
  BrandAsset(
    'assets/icon/app_icon_foreground.png',
    size: 1024,
    markShare: _sideWithin(_adaptiveSafeShare) * 0.96,
  ),
  BrandAsset(
    'assets/icon/app_icon_monochrome.png',
    size: 1024,
    markShare: _sideWithin(_adaptiveSafeShare) * 0.96,
    style: ChatixMarkStyle.monochrome,
  ),
  // macOS and Windows draw an icon's own silhouette, so the bubble is the
  // plate: 824 of 1024, the share Apple's grid gives a macOS icon body.
  BrandAsset(
    'assets/icon/app_icon_mark.png',
    size: 1024,
    markShare: 824 / 1024,
  ),
  // Launch screens: the mark alone at 4x of 112 dp, the welcome screen's
  // size, so the hand-over from native splash to Flutter does not jump.
  BrandAsset(
    'assets/splash/splash_logo.png',
    size: (AppBrandMark.welcomeSize * 4).round(),
    markShare: 1,
  ),
  // Android 12+ draws its own splash: a 1152 px canvas whose centre 768 px
  // circle survives the mask. Same 112 dp mark in it.
  BrandAsset(
    'assets/splash/splash_logo_android12.png',
    size: 1152,
    markShare: AppBrandMark.welcomeSize * 4 / 1152,
  ),
];

class BrandAsset {
  const BrandAsset(
    this.path, {
    required this.size,
    required this.markShare,
    this.background,
    this.style = ChatixMarkStyle.color,
  });

  final String path;
  final int size;

  /// The mark's side as a share of [size].
  final double markShare;

  /// Null leaves the canvas transparent.
  final Color? background;

  final ChatixMarkStyle style;

  Future<void> write() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = Offset.zero & Size.square(size.toDouble());
    final ground = background;
    if (ground != null) canvas.drawRect(bounds, Paint()..color = ground);

    final side = size * markShare;
    final mark = Rect.fromCenter(
      center: bounds.center,
      width: side,
      height: side,
    );
    canvas
      ..save()
      ..translate(mark.left, mark.top);
    ChatixMarkPainter(style: style).paint(canvas, mark.size);
    canvas.restore();

    final image = await recorder.endRecording().toImage(size, size);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  }
}
