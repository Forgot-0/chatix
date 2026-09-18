import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/presentation/widgets/message_takeoff.dart';

void main() {
  Widget host({required bool reduceMotion}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: MessageTakeoff(child: SizedBox(width: 120, height: 40)),
        ),
      ),
    );
  }

  Offset childOffset(WidgetTester tester) =>
      tester.getTopLeft(find.byType(SizedBox).first);

  double childOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.descendant(
          of: find.byType(MessageTakeoff),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  testWidgets('starts below where it lands, and lands there', (tester) async {
    await tester.pumpWidget(host(reduceMotion: false));

    final start = childOffset(tester);
    expect(childOpacity(tester), lessThan(1));

    await tester.pumpAndSettle();

    final end = childOffset(tester);
    // It rises by its travel, plus the little the scale contributes: the
    // bubble grows about its bottom corner, so a smaller bubble also starts
    // with its top edge lower down.
    const scaleDrop = 40 * (1 - MessageTakeoff.fromScale);
    expect(start.dy - end.dy, closeTo(MessageTakeoff.travel + scaleDrop, 0.5));
    expect(childOpacity(tester), 1);
  });

  testWidgets('is fully opaque well before it has finished moving', (
    tester,
  ) async {
    await tester.pumpWidget(host(reduceMotion: false));

    // Halfway through: the fade is long done, the flight is not.
    await tester.pump(const Duration(milliseconds: 240));

    expect(childOpacity(tester), 1);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion puts the bubble straight where it belongs', (
    tester,
  ) async {
    await tester.pumpWidget(host(reduceMotion: true));

    final resting = childOffset(tester);
    expect(childOpacity(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pump(const Duration(milliseconds: 500));
    expect(childOffset(tester), resting);
  });
}
