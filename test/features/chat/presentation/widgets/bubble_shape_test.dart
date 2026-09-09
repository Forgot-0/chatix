import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/features/chat/presentation/widgets/bubble_shape.dart';

import '../../../../helpers/chat_golden.dart';

void main() {
  BubbleShape shape({
    required bool isOutgoing,
    bool isFirstInGroup = true,
    bool isLastInGroup = true,
  }) => BubbleShape(
    radius: 20,
    anchorRadius: 6,
    isOutgoing: isOutgoing,
    isFirstInGroup: isFirstInGroup,
    isLastInGroup: isLastInGroup,
  );

  group('corners', () {
    test('a lone bubble anchors on the author side', () {
      final mine = shape(isOutgoing: true).borderRadius;
      expect(mine.bottomRight.x, 6);
      expect(mine.bottomLeft.x, 20);
      expect(mine.topRight.x, 20);

      final theirs = shape(isOutgoing: false).borderRadius;
      expect(theirs.bottomLeft.x, 6);
      expect(theirs.bottomRight.x, 20);
      expect(theirs.topLeft.x, 20);
    });

    test('the edge away from the author stays soft all the way down', () {
      for (final first in [true, false]) {
        for (final last in [true, false]) {
          final mine = shape(
            isOutgoing: true,
            isFirstInGroup: first,
            isLastInGroup: last,
          ).borderRadius;
          expect(mine.topLeft.x, 20, reason: 'first=$first last=$last');
          expect(mine.bottomLeft.x, 20, reason: 'first=$first last=$last');
        }
      }
    });

    test('only the last bubble of a run gets the anchor', () {
      final middle = shape(
        isOutgoing: false,
        isFirstInGroup: false,
        isLastInGroup: false,
      ).borderRadius;
      final last = shape(
        isOutgoing: false,
        isFirstInGroup: false,
        isLastInGroup: true,
      ).borderRadius;

      expect(last.bottomLeft.x, 6);
      expect(middle.bottomLeft.x, 10, reason: 'joins are softer than anchors');
      expect(middle.topLeft.x, 10);
    });

    test('the first bubble of a run keeps both top corners soft', () {
      final first = shape(
        isOutgoing: false,
        isFirstInGroup: true,
        isLastInGroup: false,
      ).borderRadius;

      expect(first.topLeft.x, 20);
      expect(first.topRight.x, 20);
    });

    test('the join radius is overridable', () {
      const custom = BubbleShape(
        radius: 20,
        anchorRadius: 6,
        isOutgoing: false,
        isFirstInGroup: false,
        isLastInGroup: false,
        joinRadius: 3,
      );

      expect(custom.borderRadius.topLeft.x, 3);
    });
  });

  group('as a ShapeBorder', () {
    test('the outer path covers the rect it is given', () {
      const rect = Rect.fromLTWH(0, 0, 120, 48);
      final path = shape(isOutgoing: true).getOuterPath(rect);

      expect(path.contains(const Offset(60, 24)), isTrue);
      expect(path.contains(const Offset(200, 24)), isFalse);
    });

    test('a border inset leaves an inner path inside the outer one', () {
      const withSide = BubbleShape(
        radius: 20,
        anchorRadius: 6,
        isOutgoing: false,
        side: BorderSide(width: 4),
      );
      const rect = Rect.fromLTWH(0, 0, 120, 48);

      expect(withSide.getInnerPath(rect).getBounds().width, lessThan(120));
      expect(withSide.dimensions, isNot(EdgeInsets.zero));
    });

    test('scale keeps the geometry proportional', () {
      final scaled = shape(isOutgoing: true).scale(2) as BubbleShape;
      expect(scaled.radius, 40);
      expect(scaled.anchorRadius, 12);
    });

    test('lerp between two of them stays a bubble', () {
      final from = shape(isOutgoing: true);
      const to = BubbleShape(
        radius: 30,
        anchorRadius: 2,
        isOutgoing: true,
      );

      final middle = to.lerpFrom(from, 0.5)! as BubbleShape;
      expect(middle.radius, 25);
      expect(middle.anchorRadius, 4);
    });

    test('equal shapes compare equal, so a repaint can be skipped', () {
      expect(shape(isOutgoing: true), shape(isOutgoing: true));
      expect(shape(isOutgoing: true), isNot(shape(isOutgoing: false)));
    });
  });

  testWidgets('BubbleShape.of takes its radii from the theme', (tester) async {
    late BubbleShape built;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [ChatixTheme.light()]),
        home: Builder(
          builder: (context) {
            built = BubbleShape.of(context, isOutgoing: true);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final chatix = ChatixTheme.light();
    expect(built.radius, chatix.bubbleRadius);
    expect(built.anchorRadius, chatix.bubbleAnchorRadius);
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('a run of bubbles on the ${entry.key} theme', (
        tester,
      ) async {
        Widget bubble({
          required bool outgoing,
          required bool first,
          required bool last,
        }) => Builder(
          builder: (context) {
            final chatix = ChatixTheme.of(context);
            return Align(
              alignment: outgoing
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                // Tall enough that a 20 px corner is not clamped by the
                // height — otherwise every bubble renders as a pill and the
                // golden says nothing about the anchor.
                width: 180,
                height: 56,
                margin: const EdgeInsets.symmetric(vertical: 1),
                decoration: ShapeDecoration(
                  color: outgoing ? null : chatix.bubbleIncoming,
                  gradient: outgoing ? chatix.bubbleOutgoingGradient : null,
                  shape: BubbleShape.of(
                    context,
                    isOutgoing: outgoing,
                    isFirstInGroup: first,
                    isLastInGroup: last,
                    side: outgoing
                        ? BorderSide.none
                        : BorderSide(color: chatix.bubbleIncomingBorder),
                  ),
                ),
              ),
            );
          },
        );

        await pumpChatGolden(
          tester,
          name: 'bubble_shape_${entry.key}',
          dark: entry.value,
          surfaceSize: const Size(420, 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              bubble(outgoing: false, first: true, last: false),
              bubble(outgoing: false, first: false, last: false),
              bubble(outgoing: false, first: false, last: true),
              const SizedBox(height: 10),
              bubble(outgoing: true, first: true, last: false),
              bubble(outgoing: true, first: false, last: true),
              const SizedBox(height: 10),
              bubble(outgoing: true, first: true, last: true),
            ],
          ),
        );
      });
    }
  });
}
