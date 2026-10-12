import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/desktop/desktop_scrolling.dart';

void main() {
  Future<SmoothWheelScrollController> pumpList(
    WidgetTester tester, {
    bool reverse = false,
    bool smooth = true,
  }) async {
    final controller = SmoothWheelScrollController()..smooth = smooth;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            reverse: reverse,
            itemExtent: 50,
            itemCount: 200,
            itemBuilder: (_, index) => Text('row $index'),
          ),
        ),
      ),
    );
    return controller;
  }

  Future<void> wheel(WidgetTester tester, double dy) async {
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(200, 300)));
    await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
  }

  group('SmoothWheelScrollController', () {
    testWidgets('a notch glides to where it points instead of jumping', (
      tester,
    ) async {
      final controller = await pumpList(tester);

      await wheel(tester, 100);
      await tester.pump();
      expect(controller.offset, 0, reason: 'nothing moves on the same frame');

      await tester.pump(AppMotion.wheel ~/ 2);
      expect(controller.offset, inExclusiveRange(0, 100));

      await tester.pumpAndSettle();
      expect(controller.offset, 100);
    });

    testWidgets('notches mid-glide add up', (tester) async {
      final controller = await pumpList(tester);

      await wheel(tester, 100);
      await tester.pump(const Duration(milliseconds: 20));
      await wheel(tester, 100);
      await tester.pump(const Duration(milliseconds: 20));
      await wheel(tester, 100);
      await tester.pumpAndSettle();

      expect(controller.offset, 300);
    });

    testWidgets('a reversed list — the feed — scrolls the way the wheel '
        'turns', (tester) async {
      final controller = await pumpList(tester, reverse: true);
      controller.jumpTo(1000);
      await tester.pump();

      // Wheel down: towards the newest messages at the bottom, which in a
      // reversed list is a smaller offset.
      await wheel(tester, 100);
      await tester.pumpAndSettle();

      expect(controller.offset, 900);
    });

    testWidgets('stops at the ends', (tester) async {
      final controller = await pumpList(tester);

      await wheel(tester, -100);
      await tester.pumpAndSettle();

      expect(controller.offset, 0);
    });

    testWidgets('with reduced motion a notch is the jump it always was', (
      tester,
    ) async {
      final controller = await pumpList(tester, smooth: false);

      await wheel(tester, 100);
      await tester.pump();

      expect(controller.offset, 100);
    });

    testWidgets('a drag after a glide starts from where the list is', (
      tester,
    ) async {
      final controller = await pumpList(tester);

      await wheel(tester, 100);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -40));
      await tester.pumpAndSettle();
      final afterDrag = controller.offset;

      await wheel(tester, 100);
      await tester.pumpAndSettle();

      expect(controller.offset, closeTo(afterDrag + 100, 0.5));
    });
  });

  group('AppScrollBehavior', () {
    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < 30; i++) Text('chip $i  '),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [for (var i = 0; i < 60; i++) Text('row $i')],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'a desktop list carries a thumb that is always there',
      (tester) async {
        await pumpPage(tester);

        final scrollbars = tester.widgetList<Scrollbar>(find.byType(Scrollbar));
        expect(scrollbars, hasLength(1), reason: 'not on the horizontal strip');
        expect(scrollbars.single.thumbVisibility, isTrue);
      },
      variant: TargetPlatformVariant.desktop(),
    );

    testWidgets(
      'a phone keeps Material\'s own: no scrollbar at all',
      (tester) async {
        await pumpPage(tester);

        expect(find.byType(Scrollbar), findsNothing);
      },
      variant: TargetPlatformVariant.mobile(),
    );
  });

  test('the platform override is not left behind', () {
    expect(debugDefaultTargetPlatformOverride, isNull);
  });
}
