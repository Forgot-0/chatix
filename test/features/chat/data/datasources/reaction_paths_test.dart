import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:chatix/features/chat/domain/entities/reaction_catalog.dart';

/// `{emoji}` is a path parameter and has to be percent-encoded (api-docs
/// §5.7.1). An unencoded one turns a single reaction into a path the router
/// cannot match, which is a 404 rather than a visible failure.
void main() {
  group('encoding an emoji for the path', () {
    test('the documented example', () {
      expect(
        ChatRestDataSourceImpl.encodeEmojiPathSegment('👍'),
        '%F0%9F%91%8D',
      );
    });

    test('leaves nothing that could be read as a path', () {
      for (final emoji in ReactionCatalog.all) {
        final encoded = ChatRestDataSourceImpl.encodeEmojiPathSegment(emoji);

        expect(encoded, isNot(contains('/')), reason: emoji);
        expect(encoded, isNot(contains('?')), reason: emoji);
        expect(encoded, isNot(contains('#')), reason: emoji);
        expect(
          RegExp(r'^[A-Za-z0-9%._~!$&()*+,;=:@-]+$').hasMatch(encoded),
          isTrue,
          reason: emoji,
        );
      }
    });

    test('a zero-width joiner sequence survives the round trip', () {
      // The catalog carries several, and a client that split on the joiner
      // would send a different emoji than the one that was tapped.
      const shrug = '🤷‍♂️';
      final encoded = ChatRestDataSourceImpl.encodeEmojiPathSegment(shrug);

      expect(encoded, contains('%E2%80%8D'));
      expect(Uri.decodeComponent(encoded), shrug);
    });

    test('every catalog entry decodes back to itself', () {
      for (final emoji in ReactionCatalog.all) {
        expect(
          Uri.decodeComponent(
            ChatRestDataSourceImpl.encodeEmojiPathSegment(emoji),
          ),
          emoji,
          reason: emoji,
        );
      }
    });
  });
}
