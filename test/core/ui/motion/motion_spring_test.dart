import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/motion/motion.dart';

void main() {
  group('GestureSpring.resist', () {
    test('follows the finger one-for-one up to the threshold', () {
      expect(GestureSpring.resist(0, threshold: 40, limit: 80), 0);
      expect(GestureSpring.resist(25, threshold: 40, limit: 80), 25);
      expect(GestureSpring.resist(40, threshold: 40, limit: 80), 40);
    });

    test('a drag the other way does not move the thing at all', () {
      expect(GestureSpring.resist(-120, threshold: 40, limit: 80), 0);
    });

    test('past the threshold it keeps moving, with diminishing returns', () {
      double at(double raw) =>
          GestureSpring.resist(raw, threshold: 40, limit: 80);

      expect(at(50), greaterThan(40));
      expect(at(90), greaterThan(at(50)));

      // The same ten pixels of drag buy less travel the further out they
      // are — which is what a rubber band feels like.
      expect(at(60) - at(50), greaterThan(at(100) - at(90)));
    });

    test('never reaches the limit, however hard it is pulled', () {
      expect(
        GestureSpring.resist(100000, threshold: 40, limit: 80),
        lessThan(80),
      );
    });

    test('a zero-width band stops dead at the threshold', () {
      expect(GestureSpring.resist(500, threshold: 40, limit: 40), 40);
    });
  });

  group('GestureSpring.settle', () {
    testWidgets('springs back over several frames', (tester) async {
      late GestureSpring spring;

      await tester.pumpWidget(
        _Host(onBuild: (state) => spring = GestureSpring(vsync: state)),
      );

      spring.value = 60;
      spring.settle(velocity: 0);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final midway = spring.value;

      expect(midway, lessThan(60));
      expect(midway, greaterThan(0));

      await tester.pumpAndSettle();
      expect(spring.value, closeTo(0, 0.01));

      spring.dispose();
    });

    testWidgets('reduced motion snaps home without a frame of spring', (
      tester,
    ) async {
      late GestureSpring spring;

      await tester.pumpWidget(
        _Host(onBuild: (state) => spring = GestureSpring(vsync: state)),
      );

      spring.value = 60;
      spring.settle(velocity: 1200, reducedMotion: true);

      expect(spring.value, 0);

      spring.dispose();
    });

    testWidgets('settling somewhere it already is does nothing', (
      tester,
    ) async {
      late GestureSpring spring;

      await tester.pumpWidget(
        _Host(onBuild: (state) => spring = GestureSpring(vsync: state)),
      );

      var completed = false;
      spring.settle(velocity: 400).whenComplete(() => completed = true);
      await tester.pump();

      expect(completed, isTrue);
      expect(spring.value, 0);

      spring.dispose();
    });
  });

  group('GestureSpring.drag', () {
    testWidgets('a drag without a band is followed exactly', (tester) async {
      late GestureSpring spring;

      await tester.pumpWidget(
        _Host(onBuild: (state) => spring = GestureSpring(vsync: state)),
      );

      spring
        ..drag(12)
        ..drag(8);

      expect(spring.value, 20);

      spring.dispose();
    });

    testWidgets('a drag inside a band is rubber-banded', (tester) async {
      late GestureSpring spring;

      await tester.pumpWidget(
        _Host(onBuild: (state) => spring = GestureSpring(vsync: state)),
      );

      spring.drag(200, threshold: 40, limit: 80);

      expect(spring.value, greaterThan(40));
      expect(spring.value, lessThan(80));

      spring.dispose();
    });
  });
}

/// A widget that exists only to hand its ticker to the test.
class _Host extends StatefulWidget {
  const _Host({required this.onBuild});

  final void Function(TickerProvider vsync) onBuild;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.onBuild(this);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
