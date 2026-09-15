import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/feedback/connection_strip.dart';

/// A connection coming back by itself is not news, so what it gets is a
/// hairline: one line of small text and a two-pixel rule, collapsing to
/// nothing when there is nothing to say.
void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Column(children: [child])),
    ),
  );

  testWidgets('takes no room at all when there is nothing to say', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ConnectionStrip(
          label: 'Connecting…',
          tone: ConnectionStripTone.working,
          visible: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(ConnectionStrip)).height, 0);
    expect(find.text('Connecting…'), findsNothing);
  });

  testWidgets('is a hairline, not a banner', (tester) async {
    await tester.pumpWidget(
      host(
        const ConnectionStrip(
          label: 'Connecting…',
          tone: ConnectionStripTone.working,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Connecting…'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ConnectionStrip)).height,
      ConnectionStrip.height,
    );
    expect(ConnectionStrip.height, lessThan(32));
  });

  testWidgets('the working rule keeps moving', (tester) async {
    await tester.pumpWidget(
      host(
        const ConnectionStrip(
          label: 'Connecting…',
          tone: ConnectionStripTone.working,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    final first = tester.widget<CustomPaint>(_sweep()).painter;

    await tester.pump(const Duration(milliseconds: 400));
    final later = tester.widget<CustomPaint>(_sweep()).painter;

    expect(later, isNot(first));
  });

  testWidgets('the waiting rule does not', (tester) async {
    // Nothing is happening: the app is waiting on something outside it, and
    // a sweep would be claiming progress that is not being made.
    await tester.pumpWidget(
      host(
        const ConnectionStrip(
          label: 'Waiting for network',
          tone: ConnectionStripTone.waiting,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_sweep(), findsNothing);
    expect(find.text('Waiting for network'), findsOneWidget);
  });

  testWidgets('holds still when the platform asks for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ConnectionStrip(
          label: 'Connecting…',
          tone: ConnectionStripTone.working,
        ),
        reduceMotion: true,
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    final first = tester.widget<CustomPaint>(_sweep()).painter;

    await tester.pump(const Duration(milliseconds: 400));
    final later = tester.widget<CustomPaint>(_sweep()).painter;

    expect(later, first);
  });

  testWidgets('says out loud what it says on screen', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      host(
        const ConnectionStrip(
          label: 'Waiting for network',
          tone: ConnectionStripTone.waiting,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // One node carrying one sentence, marked live so a screen reader
    // announces it rather than leaving it to be found by exploring.
    final node = tester.getSemantics(
      find.bySemanticsLabel('Waiting for network'),
    );
    expect(node.label, 'Waiting for network');
    expect(node.flagsCollection.isLiveRegion, isTrue);

    handle.dispose();
  });
}

Finder _sweep() => find.descendant(
  of: find.byType(ConnectionStrip),
  matching: find.byType(CustomPaint),
);
