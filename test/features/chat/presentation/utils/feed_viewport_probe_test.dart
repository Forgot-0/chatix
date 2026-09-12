import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/presentation/utils/feed_viewport_probe.dart';

/// Rows in a conversation have no fixed height, so which of them the reader
/// can see is a question only the laid-out list can answer. Everything the
/// feed does with a scroll position — the read cursor, the sticky day, the
/// jump to a message — rests on this being right.
void main() {
  const rowHeight = 100.0;
  const viewport = Size(300, 500);

  final listKey = GlobalKey();
  final controller = ScrollController();

  Future<void> pumpList(
    WidgetTester tester, {
    int count = 40,
    bool reverse = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: ListView.builder(
              key: listKey,
              controller: controller,
              reverse: reverse,
              itemCount: count,
              itemBuilder: (context, index) =>
                  SizedBox(height: rowHeight, child: Text('row $index')),
            ),
          ),
        ),
      ),
    );
  }

  tearDownAll(controller.dispose);

  testWidgets('at rest it reports the rows filling the viewport', (
    tester,
  ) async {
    await pumpList(tester);

    final range = FeedViewportProbe.of(listKey.currentContext);

    // Five 100px rows fill a 500px viewport exactly.
    expect(range, isNotNull);
    expect(range!.first, 0);
    expect(range.last, 4);
  });

  testWidgets('scrolling moves the reported span', (tester) async {
    await pumpList(tester);

    controller.jumpTo(rowHeight * 10);
    await tester.pump();

    final range = FeedViewportProbe.of(listKey.currentContext)!;

    expect(range.first, 10);
    expect(range.last, 14);
  });

  testWidgets('rows built into the cache extent are not reported as seen', (
    tester,
  ) async {
    await pumpList(tester);

    controller.jumpTo(rowHeight * 10);
    await tester.pump();

    // The default cache extent builds rows above and below the viewport.
    // Counting those as read would clear a badge for messages nobody looked
    // at.
    final probed = FeedViewportProbe.of(listKey.currentContext)!;
    final built = <int>[];
    for (var index = 0; index < 40; index++) {
      if (FeedViewportProbe.childAt(listKey.currentContext, index) != null) {
        built.add(index);
      }
    }

    expect(built.first, lessThan(probed.first));
    expect(built.last, greaterThan(probed.last));
  });

  testWidgets('a reverse list reports the same span, counted from the bottom', (
    tester,
  ) async {
    await pumpList(tester, reverse: true);

    // Index 0 is pinned to the bottom; index 4 is the row at the top edge.
    final range = FeedViewportProbe.of(listKey.currentContext)!;

    expect(range.first, 0);
    expect(range.last, 4);
    expect(range.contains(3), isTrue);
    expect(range.contains(9), isFalse);
  });

  testWidgets('childAt hands back the box a built row was laid out into', (
    tester,
  ) async {
    await pumpList(tester);

    final child = FeedViewportProbe.childAt(listKey.currentContext, 2);

    expect(child, isNotNull);
    expect(child!.size.height, rowHeight);
  });

  testWidgets('a row far outside the built window has no box', (tester) async {
    await pumpList(tester);

    expect(FeedViewportProbe.childAt(listKey.currentContext, 39), isNull);
  });

  testWidgets('nothing laid out yet reports nothing rather than throwing', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());

    expect(FeedViewportProbe.of(null), isNull);
    expect(FeedViewportProbe.of(listKey.currentContext), isNull);
    expect(FeedViewportProbe.childAt(listKey.currentContext, 0), isNull);
  });
}
