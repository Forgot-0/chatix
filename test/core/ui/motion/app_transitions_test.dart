import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/motion/motion.dart';

void main() {
  Widget harness({required bool reduceMotion, required Widget child}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );
  }

  group('scaleIn', () {
    testWidgets('grows and fades the arriving surface', (tester) async {
      await tester.pumpWidget(
        harness(
          reduceMotion: false,
          child: Builder(
            builder: (context) => AppTransitions.scaleIn(
              context,
              const AlwaysStoppedAnimation<double>(0.5),
              const AlwaysStoppedAnimation<double>(0),
              const Text('sheet'),
            ),
          ),
        ),
      );

      expect(find.byType(ScaleTransition), findsOneWidget);
      expect(find.byType(FadeTransition), findsOneWidget);
      expect(find.text('sheet'), findsOneWidget);
    });

    testWidgets('reduced motion keeps the fade and drops the scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          reduceMotion: true,
          child: Builder(
            builder: (context) => AppTransitions.scaleIn(
              context,
              const AlwaysStoppedAnimation<double>(0.5),
              const AlwaysStoppedAnimation<double>(0),
              const Text('sheet'),
            ),
          ),
        ),
      );

      expect(find.byType(ScaleTransition), findsNothing);
      expect(find.byType(FadeTransition), findsOneWidget);
    });
  });

  group('ReducedMotion', () {
    testWidgets('reports the media query, and zeroes durations', (
      tester,
    ) async {
      late BuildContext still;
      late BuildContext moving;

      await tester.pumpWidget(
        Column(
          children: [
            harness(
              reduceMotion: true,
              child: Builder(
                builder: (context) {
                  still = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
            harness(
              reduceMotion: false,
              child: Builder(
                builder: (context) {
                  moving = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      );

      expect(still.prefersReducedMotion, isTrue);
      expect(still.motion(AppMotion.slow), Duration.zero);
      expect(still.motionCurve(AppMotion.curve), Curves.linear);

      expect(moving.prefersReducedMotion, isFalse);
      expect(moving.motion(AppMotion.slow), AppMotion.slow);
      expect(moving.motionCurve(AppMotion.curve), AppMotion.curve);
    });

    testWidgets('no MediaQuery at all means no preference expressed', (
      tester,
    ) async {
      late BuildContext bare;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            bare = context;
            return const SizedBox.shrink();
          },
        ),
      );

      expect(bare.prefersReducedMotion, isFalse);
    });
  });

  group('MotionSwitcher', () {
    Widget switcher(String label, {required bool reduceMotion}) {
      return harness(
        reduceMotion: reduceMotion,
        child: Center(
          child: MotionSwitcher(
            child: Text(label, key: ValueKey<String>(label)),
          ),
        ),
      );
    }

    testWidgets('cross-fades one child into the next', (tester) async {
      await tester.pumpWidget(switcher('first', reduceMotion: false));
      await tester.pumpWidget(switcher('second', reduceMotion: false));
      await tester.pump(const Duration(milliseconds: 60));

      // Mid-transition both are on screen; that is what makes it a fade
      // rather than a swap.
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('reduced motion swaps in a single frame', (tester) async {
      await tester.pumpWidget(switcher('first', reduceMotion: true));
      await tester.pumpWidget(switcher('second', reduceMotion: true));
      await tester.pump();

      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('the same child is not re-animated on a rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(switcher('only', reduceMotion: false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(switcher('only', reduceMotion: false));

      expect(find.text('only'), findsOneWidget);
      // Nothing in flight: a rebuild of the same key is not a transition.
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
