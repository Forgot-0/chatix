import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/presentation/utils/emoji_catalog.dart';

/// The emoji panel's data: every group present, nothing in two places, and
/// a search that finds what a person types for it — in their language or in
/// English.
void main() {
  group('sections', () {
    test('every group is there, in panel order', () {
      expect([
        for (final section in EmojiCatalog.sections) section.group,
      ], EmojiGroup.values);
    });

    test('no group is empty and no emoji sits in two of them', () {
      final seen = <String>{};
      for (final section in EmojiCatalog.sections) {
        expect(section.emojis, isNotEmpty, reason: '${section.group}');
        for (final emoji in section.emojis) {
          expect(seen.add(emoji), isTrue, reason: '$emoji is repeated');
        }
      }
      // Well over a thousand: the whole of Unicode's everyday set, not the
      // reaction catalog's 73.
      expect(seen.length, greaterThan(1000));
    });

    test('the smileys lead with faces', () {
      expect(EmojiCatalog.sections.first.emojis.take(3), ['😀', '😃', '😄']);
    });
  });

  group('search', () {
    test('an empty or blank query finds nothing', () {
      expect(EmojiCatalog.search('', languageCode: 'en'), isEmpty);
      expect(EmojiCatalog.search('   ', languageCode: 'en'), isEmpty);
    });

    test('finds by English keyword', () {
      final hits = EmojiCatalog.search('pizza', languageCode: 'en');

      expect(hits.first, '🍕');
    });

    test('ignores case and the spaces around the query', () {
      expect(
        EmojiCatalog.search('  PIZZA ', languageCode: 'en'),
        EmojiCatalog.search('pizza', languageCode: 'en'),
      );
    });

    test('finds by the reader\'s own language', () {
      expect(EmojiCatalog.search('пицца', languageCode: 'ru'), contains('🍕'));
      expect(EmojiCatalog.search('кот', languageCode: 'ru'), contains('🐈'));
    });

    test('English still works whatever language the app is in', () {
      expect(EmojiCatalog.search('pizza', languageCode: 'ru'), contains('🍕'));
      expect(EmojiCatalog.search('pizza', languageCode: 'ja'), contains('🍕'));
    });

    test('a language with no keywords of its own searches in English', () {
      expect(EmojiCatalog.search('pizza', languageCode: 'bn'), contains('🍕'));
    });

    test('a keyword that is the query beats one that merely contains it', () {
      final hits = EmojiCatalog.search('cat', languageCode: 'en');

      // The cats come before "cattle"-ish and "communicate"-ish matches.
      final cat = hits.indexOf('🐈');
      expect(cat, isNonNegative);
      for (final loose in ['🐄']) {
        final index = hits.indexOf(loose);
        if (index >= 0) expect(cat, lessThan(index));
      }
    });

    test('one letter does not match the inside of every word', () {
      final single = EmojiCatalog.search('z', languageCode: 'en');
      final all = EmojiCatalog.sections.fold<int>(
        0,
        (sum, section) => sum + section.emojis.length,
      );

      expect(single.length, lessThan(all ~/ 4));
    });

    test('never answers with more than it was asked for', () {
      expect(
        EmojiCatalog.search('face', languageCode: 'en', limit: 5),
        hasLength(5),
      );
      expect(
        EmojiCatalog.search('face', languageCode: 'en').length,
        lessThanOrEqualTo(EmojiCatalog.searchLimit),
      );
    });

    test('nonsense finds nothing', () {
      expect(EmojiCatalog.search('qzxjqzxj', languageCode: 'en'), isEmpty);
    });
  });
}
