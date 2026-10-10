import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/typography/middle_ellipsis_text.dart';

void main() {
  group('middleEllipsis', () {
    // Fits anything up to [limit] characters, so the search is easy to see.
    bool Function(String) upTo(int limit) =>
        (candidate) => candidate.characters.length <= limit;

    test('a name that fits is left alone', () {
      expect(
        middleEllipsis('report.pdf', fits: upTo(20), keepTail: 8),
        'report.pdf',
      );
    });

    test('the start is cut, the tail kept whole', () {
      expect(
        middleEllipsis(
          'Маршрут_поездки_март_2026.pdf',
          fits: upTo(16),
          keepTail: 8,
        ),
        'Маршрут…2026.pdf',
      );
    });

    test('the longest start that fits wins', () {
      final shown = middleEllipsis(
        'abcdefghijklmnopqrstuvwxyz.txt',
        fits: upTo(20),
        keepTail: 8,
      );
      expect(shown, 'abcdefghijk…wxyz.txt');
      expect(shown.length, 20);
    });

    test('an emoji is never split', () {
      final shown = middleEllipsis(
        '👍🏽👍🏽👍🏽👍🏽👍🏽👍🏽.pdf',
        fits: upTo(8),
        keepTail: 4,
      );
      expect(shown, '👍🏽👍🏽👍🏽….pdf');
    });

    test('when even the tail does not fit, it is all that is shown', () {
      expect(
        middleEllipsis('abcdef.pdf', fits: upTo(3), keepTail: 8),
        '…cdef.pdf',
      );
    });
  });

  group('defaultTail', () {
    test('the extension, its dot and four characters before it', () {
      expect(
        MiddleEllipsisText.defaultTail('Маршрут_поездки_март_2026.pdf'),
        8,
      );
      expect(MiddleEllipsisText.defaultTail('budget_2026_final.xlsx'), 9);
    });

    test('a name with no extension keeps six characters', () {
      expect(MiddleEllipsisText.defaultTail('README_FIRST_PLEASE'), 6);
    });

    test('never more than half the name', () {
      expect(MiddleEllipsisText.defaultTail('a.pdf'), 2);
    });
  });

  testWidgets('drawn, it keeps within its lines and its extension', (
    tester,
  ) async {
    const name =
        'Маршрут_поездки_по_Кавказу_с_ночёвками_у_озёр_и_на_перевале_'
        'Бечо_март_2026.pdf';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              child: MiddleEllipsisText(name, maxLines: 2),
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, contains('…'));
    expect(text.data, endsWith('2026.pdf'));
    expect(text.data, startsWith('Маршрут'));
    // A screen reader hears the whole name.
    expect(text.semanticsLabel, name);
    // Two lines of the ambient style, no more.
    expect(tester.getSize(find.byType(Text)).height, lessThanOrEqualTo(2 * 20));
  });
}
