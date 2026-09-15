import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/utils/text_match.dart';
import 'package:chatix/features/chat/domain/entities/message_search_terms.dart';

/// The server cuts a query into terms, lowercases them, matches the last one
/// by prefix and the rest exactly (api-docs §5.4.1). The client repeats the
/// rules for the one thing the server leaves to it: showing why a message
/// matched.
void main() {
  group('cutting a query up', () {
    test('splits on everything that is not a letter or a digit', () {
      expect(
        MessageSearchTerms.of('бюджет, договор!').terms,
        ['бюджет', 'договор'],
      );
    });

    test('lowercases, because the index does', () {
      expect(MessageSearchTerms.of('Ship IT').terms, ['ship', 'it']);
    });

    test('tsquery operators are separators, not operators', () {
      expect(MessageSearchTerms.of('ship & it').terms, ['ship', 'it']);
      expect(MessageSearchTerms.of(' & | ! ').isEmpty, isTrue);
    });

    test('digits are terms too', () {
      expect(MessageSearchTerms.of('q4 бюджет').terms, ['q4', 'бюджет']);
    });

    test('stops at the tenth term, like the server', () {
      final terms = MessageSearchTerms.of(
        List.generate(15, (i) => 'term$i').join(' '),
      );

      expect(terms.terms, hasLength(MessageSearchTerms.maxTerms));
    });

    test('an empty query has no terms', () {
      expect(MessageSearchTerms.of('   ').isEmpty, isTrue);
    });
  });

  group('picking the match out of a message', () {
    test('a prefix is highlighted inside the word it matched', () {
      final terms = MessageSearchTerms.of('догов');

      final ranges = terms.highlightsIn('подписали договор вчера');

      expect(ranges, hasLength(1));
      expect(
        'подписали договор вчера'.substring(
          ranges.single.start,
          ranges.single.end,
        ),
        'догов',
      );
    });

    test('every term is picked out, wherever it landed', () {
      final terms = MessageSearchTerms.of('бюджет догов');

      final ranges = terms.highlightsIn('бюджет на договор');

      expect(ranges, hasLength(2));
      expect(ranges.first.start, 0);
    });

    test('ranges come back in order and never overlap', () {
      final terms = MessageSearchTerms.of('ship shipping');

      final ranges = terms.highlightsIn('shipping it');

      expect(ranges, [const TextMatchRange(0, 8)]);
    });

    test('a term the text does not show is simply not highlighted', () {
      final terms = MessageSearchTerms.of('ship budget');

      expect(terms.highlightsIn('ship it'), hasLength(1));
    });

    test('nothing to find is an empty list, not a crash', () {
      expect(MessageSearchTerms.of('ship').highlightsIn(''), isEmpty);
      expect(MessageSearchTerms.of('').highlightsIn('ship it'), isEmpty);
    });
  });

  group('where the shown part should start', () {
    test('at the earliest term, whichever one that is', () {
      final terms = MessageSearchTerms.of('договор бюджет');

      expect(terms.firstMatchIn('бюджет на договор'), 0);
    });

    test('-1 when the text shows none of them', () {
      expect(MessageSearchTerms.of('ship').firstMatchIn('nothing here'), -1);
    });
  });
}
