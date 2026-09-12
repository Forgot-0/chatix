import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/typography/highlighted_text.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );

  /// The pieces the text was cut into, and whether each one is highlighted.
  List<({String text, bool isHighlighted})> spansOf(WidgetTester tester) {
    final widget = tester.widget<Text>(find.byType(Text));
    final root = widget.textSpan! as TextSpan;

    return [
      for (final child in root.children!.cast<TextSpan>())
        (text: child.text!, isHighlighted: child.style != null),
    ];
  }

  testWidgets('picks the match out of the text', (tester) async {
    await pump(
      tester,
      const HighlightedText(text: 'Design team', query: 'sign'),
    );

    expect(spansOf(tester), [
      (text: 'De', isHighlighted: false),
      (text: 'sign', isHighlighted: true),
      (text: ' team', isHighlighted: false),
    ]);
  });

  testWidgets('is blind to case, like the search that found it', (
    tester,
  ) async {
    await pump(
      tester,
      const HighlightedText(text: 'Design team', query: 'DESIGN'),
    );

    expect(spansOf(tester).first, (text: 'Design', isHighlighted: true));
  });

  testWidgets('marks every occurrence', (tester) async {
    await pump(
      tester,
      const HighlightedText(text: 'ann and anna', query: 'an'),
    );

    expect(
      spansOf(tester).where((span) => span.isHighlighted).length,
      3,
    );
  });

  testWidgets('text with no match is drawn plainly', (tester) async {
    await pump(
      tester,
      const HighlightedText(text: 'Design team', query: 'zzz'),
    );

    final widget = tester.widget<Text>(find.byType(Text));
    expect(widget.data, 'Design team');
    expect(widget.textSpan, isNull);
  });

  testWidgets('an offset the caller worked out already is used as given', (
    tester,
  ) async {
    await pump(
      tester,
      const HighlightedText(
        text: '…ship it…',
        query: 'anything else',
        matchStart: 1,
        matchLength: 4,
      ),
    );

    expect(spansOf(tester), [
      (text: '…', isHighlighted: false),
      (text: 'ship', isHighlighted: true),
      (text: ' it…', isHighlighted: false),
    ]);
  });

  testWidgets('an offset that does not fit the text is ignored', (
    tester,
  ) async {
    await pump(
      tester,
      const HighlightedText(
        text: 'short',
        query: 'short',
        matchStart: 40,
        matchLength: 4,
      ),
    );

    expect(tester.widget<Text>(find.byType(Text)).data, 'short');
  });
}
