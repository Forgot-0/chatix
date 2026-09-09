import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/router/app_page_transitions.dart';

void main() {
  Widget harness({
    required bool reduceMotion,
    required Widget Function(BuildContext, Animation<double>, Animation<double>, Widget)
    builder,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => builder(
            context,
            const AlwaysStoppedAnimation<double>(0.5),
            const AlwaysStoppedAnimation<double>(0),
            const Text('page'),
          ),
        ),
      ),
    );
  }

  group('shared axis, horizontal', () {
    testWidgets('slides and fades the incoming page', (tester) async {
      await tester.pumpWidget(
        harness(
          reduceMotion: false,
          builder: AppPageTransitions.buildSharedAxisHorizontal,
        ),
      );

      expect(find.byType(SlideTransition), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.text('page'), findsOneWidget);
    });

    testWidgets('travels the other way in an RTL locale', (tester) async {
      // At animation 0 the page is still parked at its entry offset: to the
      // right of centre when text runs left-to-right, to the left when it
      // does not. "Forward" follows the reading direction, not the x axis.
      Future<double> entryOffset(TextDirection direction) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: direction,
              child: Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Builder(
                    builder: (context) =>
                        AppPageTransitions.buildSharedAxisHorizontal(
                          context,
                          const AlwaysStoppedAnimation<double>(0),
                          const AlwaysStoppedAnimation<double>(0),
                          const Text('page'),
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
        return tester.getTopLeft(find.text('page')).dx;
      }

      final ltr = await entryOffset(TextDirection.ltr);
      final rtl = await entryOffset(TextDirection.rtl);

      expect(ltr, greaterThan(rtl));
    });

    testWidgets('reduced motion hands the page back untouched', (tester) async {
      await tester.pumpWidget(
        harness(
          reduceMotion: true,
          builder: AppPageTransitions.buildSharedAxisHorizontal,
        ),
      );

      expect(find.byType(SlideTransition), findsNothing);
      expect(find.byType(FadeTransition), findsNothing);
      expect(find.text('page'), findsOneWidget);
    });
  });

  group('fade through', () {
    testWidgets('fades and scales, but never slides', (tester) async {
      await tester.pumpWidget(
        harness(reduceMotion: false, builder: AppPageTransitions.buildFadeThrough),
      );

      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(ScaleTransition), findsWidgets);
      expect(find.byType(SlideTransition), findsNothing);
    });

    testWidgets('reduced motion hands the page back untouched', (tester) async {
      await tester.pumpWidget(
        harness(reduceMotion: true, builder: AppPageTransitions.buildFadeThrough),
      );

      expect(find.byType(FadeTransition), findsNothing);
      expect(find.byType(ScaleTransition), findsNothing);
    });
  });

  group('FadeThroughSwitcher', () {
    Widget switcher(Object key, {bool reduceMotion = false}) {
      return MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FadeThroughSwitcher(switchKey: key, child: const Text('tab')),
        ),
      );
    }

    double opacityOf(WidgetTester tester) {
      return tester
          .widget<FadeTransition>(find.byType(FadeTransition))
          .opacity
          .value;
    }

    testWidgets('the first frame is settled, not a fade from nothing', (
      tester,
    ) async {
      await tester.pumpWidget(switcher(0));
      expect(opacityOf(tester), 1);
    });

    testWidgets('a new tab replays the incoming half', (tester) async {
      await tester.pumpWidget(switcher(0));
      await tester.pumpWidget(switcher(1));
      await tester.pump();

      expect(opacityOf(tester), lessThan(1));

      await tester.pumpAndSettle();
      expect(opacityOf(tester), 1);
    });

    testWidgets('rebuilding with the same tab does not replay it', (
      tester,
    ) async {
      await tester.pumpWidget(switcher(0));
      await tester.pumpWidget(switcher(0));
      await tester.pump();

      expect(opacityOf(tester), 1);
    });

    testWidgets('reduced motion switches instantly', (tester) async {
      await tester.pumpWidget(switcher(0, reduceMotion: true));
      await tester.pumpWidget(switcher(1, reduceMotion: true));
      await tester.pump();

      expect(find.byType(FadeTransition), findsNothing);
      expect(find.text('tab'), findsOneWidget);
    });
  });
}
