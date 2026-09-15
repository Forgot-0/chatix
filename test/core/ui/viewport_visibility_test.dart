import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/widgets/viewport_visibility.dart';

/// How much of a widget the reader can actually see, measured rather than
/// guessed. This is what decides whether a video note in the feed starts
/// playing, so a widget that never reports and one that reports on every
/// frame are both wrong.
void main() {
  const rowHeight = 200.0;
  const viewportHeight = 600.0;

  late List<double> reported;
  late ScrollController scroll;

  setUp(() {
    reported = <double>[];
    scroll = ScrollController();
    addTearDown(scroll.dispose);
  });

  /// A list of [rows] boxes, the one at [watched] reporting its visibility.
  Future<void> pumpList(
    WidgetTester tester, {
    int rows = 10,
    int watched = 4,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: viewportHeight,
            child: ListView.builder(
              controller: scroll,
              itemCount: rows,
              itemExtent: rowHeight,
              itemBuilder: (context, index) => index != watched
                  ? const SizedBox(height: rowHeight)
                  : ViewportVisibility(
                      onVisibilityChanged: reported.add,
                      child: const SizedBox(
                        height: rowHeight,
                        width: double.infinity,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a row below the fold reports nothing visible', (tester) async {
    // Row 4 starts at 800, and the viewport ends at 600.
    await pumpList(tester);

    expect(reported.last, 0);
  });

  testWidgets('scrolled into the middle, it reports all of itself', (
    tester,
  ) async {
    await pumpList(tester);

    scroll.jumpTo(rowHeight * 4);
    await tester.pumpAndSettle();

    expect(reported.last, 1);
  });

  testWidgets('half over the edge reports about half', (tester) async {
    await pumpList(tester);

    // Row 4 spans 800..1000 in the content. At this offset the viewport
    // covers 300..900, so the top half of the row is on screen and the
    // bottom half is past the fold.
    scroll.jumpTo(rowHeight * 4 - viewportHeight + rowHeight / 2);
    await tester.pumpAndSettle();

    expect(reported.last, closeTo(0.5, 0.05));
  });

  testWidgets('scrolling back past it reports nothing again', (tester) async {
    await pumpList(tester);

    scroll.jumpTo(rowHeight * 4);
    await tester.pumpAndSettle();
    expect(reported.last, 1);

    scroll.jumpTo(0);
    await tester.pumpAndSettle();

    expect(reported.last, 0);
  });

  testWidgets('a reading no different from the last one is not repeated', (
    tester,
  ) async {
    await pumpList(tester);

    scroll.jumpTo(rowHeight * 4);
    await tester.pumpAndSettle();

    final settled = reported.length;
    // A frame that changes nothing about where the row sits.
    await tester.pump();
    await tester.pump();

    expect(reported.length, settled);
  });

  testWidgets('outside a scrollable it measures against the window', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ViewportVisibility(
              onVisibilityChanged: reported.add,
              child: const SizedBox(height: 100, width: 100),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(reported.last, 1);
  });
}
