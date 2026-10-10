import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/brand/chatix_logo.dart';

/// A rendered mark, read back pixel by pixel.
class _Raster {
  _Raster(this.side, this.rgba);

  final int side;
  final ByteData rgba;

  Color at(double x, double y) {
    final i = (y.round() * side + x.round()) * 4;
    return Color.fromARGB(
      rgba.getUint8(i + 3),
      rgba.getUint8(i),
      rgba.getUint8(i + 1),
      rgba.getUint8(i + 2),
    );
  }
}

Future<_Raster> _render(
  WidgetTester tester,
  ChatixMarkPainter painter, {
  int side = 200,
}) async {
  final raster = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), Size.square(side.toDouble()));
    final image = await recorder.endRecording().toImage(side, side);
    final bytes = await image.toByteData();
    image.dispose();
    return _Raster(side, bytes!);
  });
  return raster!;
}

void main() {
  group('the outline', () {
    test('is a bubble with its anchor corner bottom right', () {
      const rect = Rect.fromLTWH(0, 0, 100, 100);
      final body = ChatixMarkPainter.bodyOf(rect);

      const soft = 100 * AppBrandMark.cornerRadius;
      expect(body.tlRadius, const Radius.circular(soft));
      expect(body.trRadius, const Radius.circular(soft));
      expect(body.blRadius, const Radius.circular(soft));
      expect(
        body.brRadius,
        const Radius.circular(100 * AppBrandMark.anchorRadius),
      );
      expect(body.outerRect, rect);
    });

    test('the X is centred, and as tall as it is wide', () {
      const rect = Rect.fromLTWH(10, 20, 200, 200);
      final bounds = ChatixMarkPainter.glyphOf(rect).getBounds();

      expect(bounds.center.dx, moreOrLessEquals(rect.center.dx));
      expect(bounds.center.dy, moreOrLessEquals(rect.center.dy));
      expect(bounds.width, moreOrLessEquals(200 * AppBrandMark.glyphReach * 2));
      expect(bounds.height, moreOrLessEquals(bounds.width));
    });

    test('the X keeps clear of the corners, stroke included', () {
      const rect = Rect.fromLTWH(0, 0, 100, 100);
      const halfStroke = 100 * AppBrandMark.glyphStroke / 2;
      final reach = ChatixMarkPainter.glyphOf(
        rect,
      ).getBounds().inflate(halfStroke);

      // The X's own box, grown by half a stroke, still fits inside the
      // square the soft corners leave untouched.
      final inner = rect.deflate(100 * AppBrandMark.cornerRadius * 0.29);
      expect(inner.contains(reach.topLeft), isTrue);
      expect(inner.contains(reach.bottomRight), isTrue);
    });
  });

  group('in colour', () {
    testWidgets('fills the bubble and draws the X white across the middle', (
      tester,
    ) async {
      final raster = await _render(tester, const ChatixMarkPainter());

      // The two halves of the X meet: the very centre is part of it.
      expect(raster.at(100, 100), AppBrandMark.glyph);
      // Between the arms, the gradient shows through.
      final between = raster.at(100, 100 - 200 * AppBrandMark.glyphReach);
      expect(between.a, 1.0);
      expect(between, isNot(AppBrandMark.glyph));
    });

    testWidgets('only the anchor corner comes close to the edge', (
      tester,
    ) async {
      final raster = await _render(tester, const ChatixMarkPainter());

      const inset = 6.0;
      expect(raster.at(inset, inset).a, 0, reason: 'top left is soft');
      expect(raster.at(199 - inset, inset).a, 0, reason: 'top right is soft');
      expect(raster.at(inset, 199 - inset).a, 0, reason: 'bottom left is soft');
      expect(
        raster.at(199 - inset, 199 - inset).a,
        1.0,
        reason: 'bottom right is the anchor',
      );
    });
  });

  group('in one colour', () {
    testWidgets('cuts the X out instead of painting it', (tester) async {
      const tint = Color(0xFF123456);
      final raster = await _render(
        tester,
        const ChatixMarkPainter(
          style: ChatixMarkStyle.monochrome,
          monochromeColor: tint,
        ),
      );

      expect(raster.at(100, 100).a, 0, reason: 'the X is a hole');
      expect(raster.at(100, 100 - 200 * AppBrandMark.glyphReach), tint);
    });
  });

  group('ChatixLogo', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('is square, at the size it was asked for', (tester) async {
      await tester.pumpWidget(host(const ChatixLogo(size: 48)));

      expect(tester.getSize(find.byType(ChatixLogo)), const Size(48, 48));
    });

    testWidgets('says nothing to a screen reader unless it is labelled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(host(const ChatixLogo()));
      expect(
        find.descendant(
          of: find.byType(ChatixLogo),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(host(const ChatixLogo(semanticLabel: 'ChatiX')));
      expect(find.bySemanticsLabel('ChatiX'), findsOneWidget);

      semantics.dispose();
    });
  });

  group('goldens', () {
    for (final theme in {
      'light': AppTheme.light(),
      'dark': AppTheme.dark(),
    }.entries) {
      testGoldens('the mark at the sizes it is used at, ${theme.key}', (
        tester,
      ) async {
        await tester.pumpWidgetBuilder(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.value,
            home: const Scaffold(
              body: Center(
                child: Wrap(
                  spacing: AppSpacing.x6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChatixLogo(size: 16),
                    ChatixLogo(size: 32),
                    ChatixLogo(),
                    ChatixLogo(size: AppBrandMark.welcomeSize),
                    SizedBox.square(
                      dimension: AppBrandMark.authSize,
                      child: CustomPaint(
                        painter: ChatixMarkPainter(
                          style: ChatixMarkStyle.monochrome,
                          monochromeColor: AppPalette.mint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          wrapper: (child) => child,
          surfaceSize: const Size(480, 200),
        );

        await screenMatchesGolden(tester, 'chatix_logo_${theme.key}');
      });
    }
  });
}
