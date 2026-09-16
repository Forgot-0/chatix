import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_member_actions.dart';

ChatMemberEntity member({
  required int userId,
  required ChatRole role,
  bool isBanned = false,
  Map<String, bool> overrides = const {},
}) {
  return ChatMemberEntity(
    userId: userId,
    roleId: role.id,
    isMuted: false,
    isBanned: isBanned,
    permissionsOverrides: overrides,
  );
}

ChatEntity chat({
  ChatType type = ChatType.group,
  Map<String, bool> permissions = const {},
}) {
  return ChatEntity(
    id: 'c1',
    seqCounter: 0,
    lastActivityAt: null,
    type: type,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: permissions,
    createdBy: 1,
    memberCount: 4,
  );
}

void main() {
  final owner = member(userId: 1, role: ChatRole.owner);
  final admin = member(userId: 2, role: ChatRole.admin);
  final editor = member(userId: 3, role: ChatRole.editor);
  final plain = member(userId: 5, role: ChatRole.member);

  List<ChatMemberAction> actionsFor(
    ChatMemberEntity me,
    ChatMemberEntity target, {
    ChatEntity? source,
  }) => memberActionsFor(
    chat: source ?? chat(),
    me: me,
    target: target,
    myUserId: me.userId,
  );

  group('assignable roles (api-docs §5.3)', () {
    test('the owner may hand out everything strictly below owner', () {
      expect(assignableRolesFor(owner), [
        ChatRole.admin,
        ChatRole.editor,
        ChatRole.member,
        ChatRole.viewer,
      ]);
    });

    test('an admin cannot make anyone owner or admin', () {
      expect(assignableRolesFor(admin), [
        ChatRole.editor,
        ChatRole.member,
        ChatRole.viewer,
      ]);
    });

    test('owner is never offered — the API cannot transfer a chat', () {
      expect(assignableRolesFor(owner), isNot(contains(ChatRole.owner)));
    });

    test('`direct` is never offered — it belongs to 1:1 chats only', () {
      expect(assignableRolesFor(owner), isNot(contains(ChatRole.direct)));
      expect(assignableRolesFor(admin), isNot(contains(ChatRole.direct)));
    });

    test('a member with no role above theirs may assign nothing', () {
      expect(
        assignableRolesFor(member(userId: 6, role: ChatRole.viewer)),
        isEmpty,
      );
    });
  });

  group('what one member may do to another (api-docs §8.1)', () {
    test('the owner may change roles, kick and ban an ordinary member', () {
      expect(actionsFor(owner, plain), [
        ChatMemberAction.openProfile,
        ChatMemberAction.message,
        ChatMemberAction.changeRole,
        ChatMemberAction.kick,
        ChatMemberAction.ban,
      ]);
    });

    test('an editor holds none of the member permissions', () {
      expect(actionsFor(editor, plain), [
        ChatMemberAction.openProfile,
        ChatMemberAction.message,
      ]);
    });

    test('nobody may moderate the owner, not even another owner', () {
      expect(actionsFor(admin, owner), [
        ChatMemberAction.openProfile,
        ChatMemberAction.message,
      ]);
    });

    test('there is nothing to do to yourself but read your own profile', () {
      expect(actionsFor(owner, owner), [ChatMemberAction.openProfile]);
    });

    test('a banned member is offered an unban instead of a ban', () {
      final banned = member(userId: 9, role: ChatRole.member, isBanned: true);
      final actions = actionsFor(owner, banned);

      expect(actions, contains(ChatMemberAction.unban));
      expect(actions, isNot(contains(ChatMemberAction.ban)));
      expect(actions, isNot(contains(ChatMemberAction.changeRole)));
    });

    test(
      'muting is never offered: the members router has no mute endpoint',
      () {
        // Regression guard for the gap in docs/BACKEND_GAPS.md. `member:mute`
        // is in the permission matrix (api-docs §8.1) but the members router
        // has no endpoint to send it to, so nothing may offer the action.
        final mute = matches(RegExp('mute', caseSensitive: false));

        expect(
          ChatMemberAction.values.map((a) => a.name),
          isNot(contains(mute)),
        );
        for (final target in [plain, admin, editor]) {
          expect(
            actionsFor(owner, target).map((a) => a.name),
            isNot(contains(mute)),
          );
        }
      },
    );

    test('a chat-level override can take member:kick away from an admin', () {
      final restricted = chat(permissions: const {'member:kick': false});
      expect(
        actionsFor(admin, plain, source: restricted),
        isNot(contains(ChatMemberAction.kick)),
      );
    });

    test('a personal override can hand member:ban to an editor', () {
      final promoted = member(
        userId: 3,
        role: ChatRole.editor,
        overrides: const {'member:ban': true},
      );
      expect(actionsFor(promoted, plain), contains(ChatMemberAction.ban));
    });
  });

  group('changing a role', () {
    test('is offered only when some other role is actually available', () {
      expect(canChangeRoleOf(chat(), owner, plain), isTrue);
    });

    test('is withheld when the target already holds the only option', () {
      final nearlyPowerless = member(userId: 4, role: ChatRole.member);
      final viewerOnly = member(
        userId: 8,
        role: ChatRole.viewer,
        overrides: const {'role:change': true},
      );

      // A viewer can only assign roles below viewer, and there are none.
      expect(canChangeRoleOf(chat(), viewerOnly, nearlyPowerless), isFalse);
    });

    test('is withheld for a banned member', () {
      final banned = member(userId: 9, role: ChatRole.member, isBanned: true);
      expect(canChangeRoleOf(chat(), owner, banned), isFalse);
    });
  });

  group('ban durations (api-docs §5.3)', () {
    final now = DateTime.utc(2026, 5, 17, 12);

    test('a permanent ban sends no expiry at all', () {
      expect(banExpiryFor(BanDuration.forever, now: now), isNull);
    });

    test('the fixed spans land in the future', () {
      expect(
        banExpiryFor(BanDuration.hour, now: now),
        DateTime.utc(2026, 5, 17, 13),
      );
      expect(
        banExpiryFor(BanDuration.day, now: now),
        DateTime.utc(2026, 5, 18, 12),
      );
      expect(
        banExpiryFor(BanDuration.week, now: now),
        DateTime.utc(2026, 5, 24, 12),
      );
    });

    test('a chosen date is passed through untouched', () {
      final date = DateTime.utc(2026, 8, 1);
      expect(banExpiryFor(BanDuration.untilDate, now: now, date: date), date);
    });

    test('every option but a date is ready to send immediately', () {
      for (final duration in BanDuration.values) {
        expect(
          isBanRequestComplete(duration, now: now),
          duration != BanDuration.untilDate,
          reason: '$duration',
        );
      }
    });

    test('a date in the past is not a ban and is refused here', () {
      expect(
        isBanRequestComplete(
          BanDuration.untilDate,
          now: now,
          date: DateTime.utc(2026, 5, 1),
        ),
        isFalse,
      );
    });
  });
}
