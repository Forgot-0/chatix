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

  /// Pushes, lets the flight land, then pops and reads the clip [at] into
  /// the way back.
  Future<({BorderRadius radius, Size box, ClipRRect clip})> clipDuringPop(
    WidgetTester tester, {
    required HeroFlightShuttleBuilder shuttle,
    required Duration at,
  }) async {
    final navigator = GlobalKey<NavigatorState>();

    Widget thing(double side, Color color) => SizedBox(
      width: side,
      height: side,
      child: Hero(
        tag: 'thing',
        flightShuttleBuilder: shuttle,
        child: ColoredBox(color: color),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(body: Center(child: thing(40, const Color(0xFF112233)))),
      ),
    );

    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: thing(200, const Color(0xFF445566))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(at);

    final finder = find.byType(ClipRRect).first;
    final clip = tester.widget<ClipRRect>(finder);

    return (
      radius: clip.borderRadius as BorderRadius,
      box: tester.getSize(finder),
      clip: clip,
    );
  }

  testWidgets('on the way back the corners return the way they came: square '
      'as it leaves the viewer, round as it lands', (tester) async {
    final shuttle = AppHeroFlight.corners(fromFactor: 0.5, toFactor: 0);

    final leaving = await clipDuringPop(
      tester,
      shuttle: shuttle,
      at: const Duration(milliseconds: 16),
    );
    await tester.pumpAndSettle();

    final landing = await clipDuringPop(
      tester,
      shuttle: shuttle,
      at: const Duration(milliseconds: 290),
    );
    await tester.pumpAndSettle();

    // Leaving the big end, it still has that end's square corners — not the
    // small end's circle stuck onto a full-size box.
    expect(leaving.radius.topLeft.x / leaving.box.shortestSide, lessThan(0.05));
    expect(
      landing.radius.topLeft.x / landing.box.shortestSide,
      greaterThan(0.3),
    );
  });

  testWidgets('a cross-fading flight keeps the source under the destination', (
    tester,
  ) async {
    final shuttle = AppHeroFlight.corners(
      fromFactor: 0.03,
      toFactor: 0,
      crossFade: true,
    );

    final mid = await clipDuringPop(
      tester,
      shuttle: shuttle,
      at: const Duration(milliseconds: 150),
    );

    final colors = find
        .descendant(
          of: find.byWidget(mid.clip),
          matching: find.byType(ColoredBox),
        )
        .evaluate()
        .map((element) => (element.widget as ColoredBox).color)
        .toList();

    // The small end's picture underneath, the big end's fading over it.
    expect(colors, [const Color(0xFF112233), const Color(0xFF445566)]);
    expect(
      find.descendant(
        of: find.byWidget(mid.clip),
        matching: find.byType(Opacity),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });
}

/// A push we deliberately do not await: the flight is what is under test.
void unawaited(Future<void> future) {}
