import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';

ReactionGroupEntity chip(
  String emoji, {
  int count = 1,
  int version = 0,
  bool reactedByMe = false,
  List<int> recentUserIds = const [],
}) => ReactionGroupEntity(
  emoji: emoji,
  count: count,
  version: version,
  reactedByMe: reactedByMe,
  recentUserIds: recentUserIds,
);

MessageReactionsEntity reactions(List<ReactionGroupEntity> groups) =>
    MessageReactionsEntity(messageId: 'm1', groups: groups);

void main() {
  group('a user holds a set of emoji, not one (§6.7.2)', () {
    test('adding a second emoji keeps the first', () {
      final before = reactions([chip('👍', count: 1, reactedByMe: true)]);

      final after = before.addMine('🔥');

      expect(after.myEmojis, ['👍', '🔥']);
      expect(after.groups.firstWhere((g) => g.emoji == '👍').count, 1);
      expect(after.groups.firstWhere((g) => g.emoji == '🔥').count, 1);
    });

    test('myEmojis reports every group flagged as ours', () {
      final summary = reactions([
        chip('👍', reactedByMe: true),
        chip('😀'),
        chip('🔥', reactedByMe: true),
      ]);

      expect(summary.myEmojis, ['👍', '🔥']);
      expect(summary.isMine('😀'), isFalse);
    });

    test('adding an emoji already held is a no-op, like the server', () {
      final before = reactions([chip('👍', count: 3, reactedByMe: true)]);

      expect(before.addMine('👍'), before);
    });

    test('the per-user cap of 3 is enforced locally', () {
      final full = reactions([
        chip('👍', reactedByMe: true),
        chip('🔥', reactedByMe: true),
        chip('😀', reactedByMe: true),
      ]);

      expect(full.canAddMore, isFalse);
      expect(full.addMine('🎉'), full);
    });

    test('joining an existing group only bumps its count', () {
      final before = reactions([chip('👍', count: 5)]);

      final after = before.addMine('👍', myUserId: 7);

      expect(after.groups.single.count, 6);
      expect(after.groups.single.reactedByMe, isTrue);
      expect(after.groups.single.recentUserIds.first, 7);
    });

    test('removing one of several leaves the others alone', () {
      final before = reactions([
        chip('👍', count: 2, reactedByMe: true),
        chip('🔥', count: 1, reactedByMe: true),
      ]);

      final after = before.removeMine('👍');

      expect(after.myEmojis, ['🔥']);
      expect(after.groups.firstWhere((g) => g.emoji == '👍').count, 1);
    });

    test('removing the last holder drops the chip rather than showing 0', () {
      final before = reactions([chip('👍', count: 1, reactedByMe: true)]);

      expect(before.removeMine('👍').groups, isEmpty);
    });

    test('removing an emoji we never held is a no-op', () {
      final before = reactions([chip('👍', count: 4)]);

      expect(before.removeMine('👍'), before);
    });

    test('toggleMine adds when absent and removes when held', () {
      final empty = reactions(const []);

      final added = empty.toggleMine('👍');
      expect(added.myEmojis, ['👍']);

      expect(added.toggleMine('👍').myEmojis, isEmpty);
    });
  });

  group('replaceMine — whole-set semantics of PUT .../reactions/', () {
    test('drops what is not wanted and adds what is', () {
      final before = reactions([
        chip('👍', count: 2, reactedByMe: true),
        chip('🔥', count: 1, reactedByMe: true),
      ]);

      final after = before.replaceMine(['🔥', '🎉']);

      expect(after.myEmojis, ['🔥', '🎉']);
      expect(after.groups.firstWhere((g) => g.emoji == '👍').count, 1);
    });

    test('an empty list clears every one of our reactions', () {
      final before = reactions([
        chip('👍', count: 1, reactedByMe: true),
        chip('🔥', count: 1, reactedByMe: true),
      ]);

      expect(before.replaceMine(const []).myEmojis, isEmpty);
    });

    test('more than the cap is trimmed instead of over-sending', () {
      final after = reactions(
        const [],
      ).replaceMine(['👍', '🔥', '😀', '🎉', '❤️']);

      expect(after.myEmojis.length, ReactionLimits.maxPerUserPerMessage);
    });
  });

  group('applySnapshot — folding a reaction_update (§6.7.6)', () {
    test('takes the counts but keeps our own flags', () {
      final local = reactions([chip('👍', count: 1, reactedByMe: true)]);

      final after = local.applySnapshot([
        chip('👍', count: 9, version: 1),
        chip('🔥', count: 2, version: 1),
      ]);

      expect(after.groups.firstWhere((g) => g.emoji == '👍').count, 9);
      expect(after.groups.firstWhere((g) => g.emoji == '👍').reactedByMe, isTrue);
      expect(after.groups.firstWhere((g) => g.emoji == '🔥').reactedByMe, isFalse);
    });

    test('replaces wholesale — a group absent from the snapshot is gone', () {
      final local = reactions([chip('👍', count: 1), chip('🔥', count: 1)]);

      final after = local.applySnapshot([chip('👍', count: 1, version: 1)]);

      expect(after.groups.map((g) => g.emoji), ['👍']);
    });

    test('an out-of-order frame is rejected per group by version', () {
      final local = reactions([chip('👍', count: 10, version: 5)]);

      final after = local.applySnapshot([chip('👍', count: 2, version: 3)]);

      expect(after.groups.single.count, 10);
      expect(after.groups.single.version, 5);
    });

    test('an equal or newer version is applied', () {
      final local = reactions([chip('👍', count: 10, version: 5)]);

      expect(local.applySnapshot([chip('👍', count: 2, version: 5)]).groups.single.count, 2);
      expect(local.applySnapshot([chip('👍', count: 2, version: 6)]).groups.single.count, 2);
    });

    test('our own action from another device is read off the snapshot', () {
      final local = reactions([chip('👍', count: 1)]);

      final after = local.applySnapshot(
        [
          chip('👍', count: 1, version: 1),
          chip('🔥', count: 1, version: 1, recentUserIds: const [7]),
        ],
        actorId: 7,
        myUserId: 7,
      );

      expect(after.groups.firstWhere((g) => g.emoji == '🔥').reactedByMe, isTrue);
    });

    test("someone else's recent_user_ids never marks a chip as ours", () {
      final local = reactions([chip('👍', count: 1)]);

      final after = local.applySnapshot(
        [chip('👍', count: 2, version: 1, recentUserIds: const [7])],
        actorId: 8,
        myUserId: 7,
      );

      expect(after.groups.single.reactedByMe, isFalse);
    });

    test('a truncated recent_user_ids does not un-flag our own chip', () {
      final local = reactions([chip('👍', count: 50, reactedByMe: true)]);

      final after = local.applySnapshot(
        [chip('👍', count: 51, version: 1, recentUserIds: const [1, 2, 3])],
        actorId: 7,
        myUserId: 7,
      );

      expect(after.groups.single.reactedByMe, isTrue);
    });
  });

  group('limits mirror §6.7.4 exactly', () {
    test('the documented constants', () {
      expect(ReactionLimits.maxPerUserPerMessage, 3);
      expect(ReactionLimits.maxDistinctPerMessage, 20);
      expect(ReactionLimits.maxEmojiLength, 32);
      expect(ReactionLimits.recentUsersLimit, 3);
    });

    test('canAddMore is false once the message has 20 distinct emoji', () {
      final crowded = reactions([
        for (var i = 0; i < ReactionLimits.maxDistinctPerMessage; i++)
          chip('e$i'),
      ]);

      expect(crowded.canAddMore, isFalse);
    });
  });

  group('ReactionAction', () {
    test('parses the four documented verbs', () {
      expect(ReactionAction.fromWire('add'), ReactionAction.add);
      expect(ReactionAction.fromWire('remove'), ReactionAction.remove);
      expect(ReactionAction.fromWire('replace'), ReactionAction.replace);
      expect(ReactionAction.fromWire('update'), ReactionAction.update);
    });

    test('an unknown verb degrades to update rather than dropping the event', () {
      expect(ReactionAction.fromWire('exploded'), ReactionAction.update);
      expect(ReactionAction.fromWire(null), ReactionAction.update);
    });
  });
}
