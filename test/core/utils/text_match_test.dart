import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/utils/text_match.dart';

void main() {
  group('findMatches', () {
    test('finds every occurrence, ignoring case', () {
      final ranges = findMatches('Ann and anna', 'an');

      expect(ranges, const [
        TextMatchRange(0, 2),
        TextMatchRange(4, 6),
        TextMatchRange(8, 10),
      ]);
    });

    test('does not overlap a match with itself', () {
      expect(findMatches('aaaa', 'aa'), const [
        TextMatchRange(0, 2),
        TextMatchRange(2, 4),
      ]);
    });

    test('an empty needle or haystack matches nothing', () {
      expect(findMatches('hello', ''), isEmpty);
      expect(findMatches('', 'hello'), isEmpty);
    });

    test('stops at the limit', () {
      expect(findMatches('aaaaaa', 'a', limit: 2), hasLength(2));
    });
  });

  test('containsIgnoreCase is case blind', () {
    expect(containsIgnoreCase('Design Team', 'team'), isTrue);
    expect(containsIgnoreCase('Design Team', 'TEAM'), isTrue);
    expect(containsIgnoreCase('Design Team', 'teams'), isFalse);
  });

  group('snippetAround', () {
    test('leaves a short message alone and points at the match', () {
      final snippet = snippetAround('ship it tomorrow', 'it');

      expect(snippet.text, 'ship it tomorrow');
      expect(snippet.matchStart, 5);
      expect(snippet.matchLength, 2);
    });

    test('collapses the whitespace a row cannot show anyway', () {
      final snippet = snippetAround('ship\n\n  it', 'it');

      expect(snippet.text, 'ship it');
      expect(snippet.matchStart, 5);
    });

    test('cuts a long message down to a window around the match', () {
      final text = '${'x' * 400}needle${'y' * 400}';
      final snippet = snippetAround(text, 'needle', maxLength: 60, lead: 10);

      expect(snippet.text.length, lessThanOrEqualTo(62));
      expect(snippet.text.startsWith('…'), isTrue);
      expect(snippet.text.endsWith('…'), isTrue);
      expect(
        snippet.text.substring(
          snippet.matchStart,
          snippet.matchStart + snippet.matchLength,
        ),
        'needle',
      );
    });

    test('a match near the end still comes with its context', () {
      final text = '${'x' * 200}needle';
      final snippet = snippetAround(text, 'needle', maxLength: 40, lead: 10);

      expect(snippet.text.endsWith('needle'), isTrue);
      expect(
        snippet.text.substring(
          snippet.matchStart,
          snippet.matchStart + snippet.matchLength,
        ),
        'needle',
      );
    });

    test('text without the needle comes back trimmed, with no match', () {
      final snippet = snippetAround('nothing here', 'absent');

      expect(snippet.hasMatch, isFalse);
      expect(snippet.text, 'nothing here');
    });
  });
}
