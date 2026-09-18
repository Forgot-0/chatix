import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/motion/motion.dart';

void main() {
  /// Pushes a route with a matching Hero and reads the clip the shuttle is
  /// drawing mid-flight.
  Future<({BorderRadius radius, Size box})> clipDuringFlight(
    WidgetTester tester, {
    required double fromFactor,
    required double toFactor,
    required Duration at,
  }) async {
    final shuttle = AppHeroFlight.corners(
      fromFactor: fromFactor,
      toFactor: toFactor,
    );

    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: Hero(
                tag: 'thing',
                flightShuttleBuilder: shuttle,
                child: const ColoredBox(color: Color(0xFF112233)),
              ),
            ),
          ),
        ),
      ),
    );

    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: Hero(
                tag: 'thing',
                flightShuttleBuilder: shuttle,
                child: const ColoredBox(color: Color(0xFF112233)),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(at);

    final finder = find.byType(ClipRRect).first;
    final clip = tester.widget<ClipRRect>(finder);

    return (
      radius: clip.borderRadius as BorderRadius,
      box: tester.getSize(finder),
    );
  }

  testWidgets('a circle relaxes into a square corner as it flies', (
    tester,
  ) async {
    final early = await clipDuringFlight(
      tester,
      fromFactor: 0.5,
      toFactor: 0,
      at: const Duration(milliseconds: 40),
    );
    await tester.pumpAndSettle();

    final settled = await clipDuringFlight(
      tester,
      fromFactor: 0.5,
      toFactor: 0,
      at: const Duration(milliseconds: 260),
    );
    await tester.pumpAndSettle();

    expect(early.radius.topLeft.x, greaterThan(settled.radius.topLeft.x));
    expect(settled.radius.topLeft.x, greaterThanOrEqualTo(0));
  });

  testWidgets('a circle that stays a circle keeps half its box', (
    tester,
  ) async {
    final mid = await clipDuringFlight(
      tester,
      fromFactor: 0.5,
      toFactor: 0.5,
      at: const Duration(milliseconds: 150),
    );
    await tester.pumpAndSettle();

    // Whatever size the flight is at, the clip is half of it — which is the
    // only way a circle stays round while it grows.
    expect(mid.radius.topLeft.x, closeTo(mid.box.shortestSide / 2, 0.01));
  });
}

/// A push we deliberately do not await: the flight is what is under test.
void unawaited(Future<void> future) {}
