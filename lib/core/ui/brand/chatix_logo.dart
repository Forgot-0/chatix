import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// How the mark is coloured.
enum ChatixMarkStyle {
  /// The brand gradient with a white X — the logo.
  color,

  /// One flat colour with the X cut out of it, for places that tint the
  /// mark themselves: Android's themed icons, a notification badge.
  monochrome,
}

/// The ChatiX logo: an outgoing bubble, anchor corner bottom right, with a
/// white X in it.
///
/// Decorative by default — on the sign-in screens the headline beside it
/// already says where the reader is. Pass [semanticLabel] where the mark is
/// the only thing naming the app.
class ChatixLogo extends StatelessWidget {
  const ChatixLogo({
    super.key,
    this.size = AppBrandMark.authSize,
    this.semanticLabel,
  });

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: ChatixMarkPainter()),
    );

    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: mark);
    return Semantics(label: label, image: true, child: mark);
  }
}

/// Paints the mark into the largest square that fits the canvas, centred.
///
/// Public because the launcher icons and splash images are rendered from
/// this same painter (`tool/brand/export_brand_assets_test.dart`), so the
/// icon on the home screen and the logo on the sign-in screen cannot drift
/// apart.
class ChatixMarkPainter extends CustomPainter {
  const ChatixMarkPainter({
    this.style = ChatixMarkStyle.color,
    this.monochromeColor = AppBrandMark.glyph,
  });

  final ChatixMarkStyle style;

  /// The fill when [style] is [ChatixMarkStyle.monochrome].
  final Color monochromeColor;

  /// The bubble's outline inside [rect].
  static RRect bodyOf(Rect rect) {
    final side = rect.shortestSide;
    final soft = Radius.circular(side * AppBrandMark.cornerRadius);
    return RRect.fromRectAndCorners(
      rect,
      topLeft: soft,
      topRight: soft,
      bottomLeft: soft,
      bottomRight: Radius.circular(side * AppBrandMark.anchorRadius),
    );
  }

  /// The X inside [rect], as the centre lines of its two bowed strokes.
  static Path glyphOf(Rect rect) {
    final reach = rect.shortestSide * AppBrandMark.glyphReach;
    final bow = reach * AppBrandMark.glyphBow;
    final c = rect.center;
    return Path()
      // The left half: a ")" whose belly reaches the centre…
      ..moveTo(c.dx - reach, c.dy - reach)
      ..quadraticBezierTo(c.dx + bow, c.dy, c.dx - reach, c.dy + reach)
      // …and the right half, a "(" leaning into it.
      ..moveTo(c.dx + reach, c.dy - reach)
      ..quadraticBezierTo(c.dx - bow, c.dy, c.dx + reach, c.dy + reach);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Alignment.center.inscribe(
      Size.square(size.shortestSide),
      Offset.zero & size,
    );
    if (rect.isEmpty) return;

    final body = bodyOf(rect);
    final glyph = glyphOf(rect);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rect.shortestSide * AppBrandMark.glyphStroke
      ..strokeCap = StrokeCap.round;

    switch (style) {
      case ChatixMarkStyle.color:
        canvas.drawRRect(
          body,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppBrandMark.gradientStart, AppBrandMark.gradientEnd],
            ).createShader(rect),
        );
        canvas.drawRRect(
          body,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.7, -0.75),
              radius: 0.85,
              colors: [
                AppBrandMark.bloom.withValues(alpha: AppBrandMark.bloomAlpha),
                AppBrandMark.bloom.withValues(alpha: 0),
              ],
            ).createShader(rect),
        );
        canvas.drawPath(glyph, stroke..color = AppBrandMark.glyph);
      case ChatixMarkStyle.monochrome:
        // The X is a hole, not white paint: whatever tints the mark must
        // show the ground through it.
        canvas.saveLayer(rect, Paint());
        canvas.drawRRect(body, Paint()..color = monochromeColor);
        canvas.drawPath(glyph, stroke..blendMode = BlendMode.clear);
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ChatixMarkPainter oldDelegate) =>
      style != oldDelegate.style ||
      monochromeColor != oldDelegate.monochromeColor;
}
