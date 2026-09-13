import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/reaction_catalog.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';

/// The server accepts a curated list and refuses everything else with
/// `INVALID_REACTION` (api-docs §5.7.2). Nothing outside it may ever reach a
/// picker, so the list itself is worth pinning down.
void main() {
  group('the catalog', () {
    test('carries the ~73 emoji the server curates', () {
      expect(ReactionCatalog.all, hasLength(73));
    });

    test('lists nothing twice', () {
      expect(
        ReactionCatalog.all.toSet(),
        hasLength(ReactionCatalog.all.length),
      );
    });

    test('sections partition it — everything in exactly one drawer', () {
      final fromSections = [
        for (final section in ReactionCatalog.sections.values) ...section,
      ];

      expect(fromSections, hasLength(ReactionCatalog.all.length));
      expect(fromSections.toSet(), ReactionCatalog.all.toSet());
    });

    test('every entry fits MAX_REACTION_LENGTH', () {
      for (final emoji in ReactionCatalog.all) {
        expect(
          emoji.length,
          lessThanOrEqualTo(ReactionLimits.maxEmojiLength),
          reason: emoji,
        );
        expect(SetReactionUseCase.validateEmoji(emoji), isNull, reason: emoji);
      }
    });

    test('isKnown answers for members and non-members', () {
      expect(ReactionCatalog.isKnown('👍'), isTrue);
      expect(ReactionCatalog.isKnown('🫠'), isFalse);
      expect(ReactionCatalog.isKnown(''), isFalse);
    });
  });

  group('the quick defaults', () {
    test('are all in the catalog', () {
      // A default the server refuses would make the first reaction anyone
      // ever sends the one that fails.
      for (final emoji in ReactionCatalog.quickDefaults) {
        expect(ReactionCatalog.isKnown(emoji), isTrue, reason: emoji);
      }
    });

    test('fill the bar exactly once each', () {
      expect(
        ReactionCatalog.quickDefaults,
        hasLength(ReactionCatalog.quickBarLength),
      );
      expect(
        ReactionCatalog.quickDefaults.toSet(),
        hasLength(ReactionCatalog.quickBarLength),
      );
    });
  });

  group('the chat policy is the one gate', () {
    test('"all" still means only what the server knows', () {
      expect(ChatReactionPolicy.unrestricted.isAllowed('👍'), isTrue);
      expect(ChatReactionPolicy.unrestricted.isAllowed('🫠'), isFalse);
    });

    test('"some" narrows the catalog to the white list', () {
      const policy = ChatReactionPolicy(enabled: true, whitelist: ['👍', '🔥']);

      expect(policy.available, ['👍', '🔥']);
    });

    test('a white list entry outside the catalog is still refused', () {
      const policy = ChatReactionPolicy(enabled: true, whitelist: ['🫠']);

      expect(policy.isAllowed('🫠'), isFalse);
      expect(policy.available, isEmpty);
    });

    test('"none" offers nothing at all', () {
      const policy = ChatReactionPolicy(enabled: false);

      expect(policy.available, isEmpty);
      expect(policy.isAllowed('👍'), isFalse);
    });

    test('available keeps catalog order, not white-list order', () {
      const policy = ChatReactionPolicy(enabled: true, whitelist: ['🔥', '👍']);

      expect(policy.available, ['👍', '🔥']);
    });
  });
}
