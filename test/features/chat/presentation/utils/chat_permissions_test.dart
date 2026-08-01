import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';

/// Covers the api-docs §9.1 permission model: the role matrix itself and the
/// three-layer merge (role → chat override → member override) the UI uses to
/// decide which controls to render.
///
/// The backend performs the authoritative merge; this mirrors it so a button
/// is not shown for an action that is guaranteed to 403. Both directions of
/// override matter — a layer may *revoke* a right the role grants, not only
/// grant one it denies — which is why presence of the key is what counts, not
/// truthiness.
ChatEntity chatWith({
  Map<String, bool> permissions = const {},
  ChatType type = ChatType.group,
  bool adminOnly = false,
  List<ChatMemberEntity>? members,
}) {
  return ChatEntity(
    id: 'a3f1c2d4-0000-4000-8000-000000000001',
    seqCounter: 0,
    lastActivityAt: null,
    type: type,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: adminOnly,
    slowModeSeconds: 0,
    permissions: permissions,
    createdBy: 1,
    memberCount: 2,
    members: members,
  );
}

ChatMemberEntity memberWith({
  int userId = 2,
  required int roleId,
  bool isMuted = false,
  bool isBanned = false,
  Map<String, bool> overrides = const {},
}) {
  return ChatMemberEntity(
    userId: userId,
    roleId: roleId,
    isMuted: isMuted,
    isBanned: isBanned,
    permissionsOverrides: overrides,
  );
}

void main() {
  group('role matrix (api-docs §9.1)', () {
    test('owner may delete the chat, admin may not', () {
      final chat = chatWith();
      expect(
        hasChatPermission(chat, memberWith(roleId: 1), ChatPermissions.chatDelete),
        isTrue,
      );
      expect(
        hasChatPermission(chat, memberWith(roleId: 2), ChatPermissions.chatDelete),
        isFalse,
      );
    });

    test('viewer may read but not send — the channel subscriber case', () {
      final chat = chatWith(type: ChatType.channel);
      final viewer = memberWith(roleId: 6);

      expect(
        hasChatPermission(chat, viewer, ChatPermissions.messageRead),
        isTrue,
      );
      expect(
        hasChatPermission(chat, viewer, ChatPermissions.messageSend),
        isFalse,
      );
      expect(canSendMessage(chat, viewer), isFalse);
    });

    test('role_id=4 (direct) may chat:update while member (5) may not', () {
      // The pair that makes "order roles by power" meaningless: `direct` is
      // not a weaker `member`, it is a different row of the matrix.
      final chat = chatWith(type: ChatType.direct);

      expect(
        hasChatPermission(chat, memberWith(roleId: 4), ChatPermissions.chatUpdate),
        isTrue,
      );
      expect(
        hasChatPermission(chat, memberWith(roleId: 5), ChatPermissions.chatUpdate),
        isFalse,
      );
    });

    test('direct (4) cannot delete messages while editor (3) can', () {
      final chat = chatWith();

      expect(
        hasChatPermission(
          chat,
          memberWith(roleId: 4),
          ChatPermissions.messageDelete,
        ),
        isFalse,
      );
      expect(
        hasChatPermission(
          chat,
          memberWith(roleId: 3),
          ChatPermissions.messageDelete,
        ),
        isTrue,
      );
    });

    test('an unknown role_id grants nothing (fail-closed)', () {
      final chat = chatWith();
      // A role added to the backend seed after this build.
      final unknown = memberWith(roleId: 99);

      expect(unknown.role, isNull);
      expect(
        hasChatPermission(chat, unknown, ChatPermissions.messageSend),
        isFalse,
      );
    });

    test('a non-member is denied everything', () {
      final chat = chatWith();
      expect(hasChatPermission(chat, null, ChatPermissions.messageRead), isFalse);
      expect(canSendMessage(chat, null), isFalse);
    });
  });

  group('override layering (api-docs §9.1)', () {
    test('a chat-level override GRANTS a right the role denies', () {
      final chat = chatWith(permissions: {ChatPermissions.messageDelete: true});
      expect(
        hasChatPermission(
          chat,
          memberWith(roleId: 5),
          ChatPermissions.messageDelete,
        ),
        isTrue,
      );
    });

    test('a chat-level override REVOKES a right the role grants', () {
      final chat = chatWith(permissions: {ChatPermissions.messageSend: false});
      expect(
        hasChatPermission(
          chat,
          memberWith(roleId: 5),
          ChatPermissions.messageSend,
        ),
        isFalse,
      );
    });

    test('a member override beats the chat override, both directions', () {
      final revokingChat = chatWith(
        permissions: {ChatPermissions.messageSend: false},
      );
      expect(
        hasChatPermission(
          revokingChat,
          memberWith(roleId: 5, overrides: {ChatPermissions.messageSend: true}),
          ChatPermissions.messageSend,
        ),
        isTrue,
      );

      final grantingChat = chatWith(
        permissions: {ChatPermissions.messageSend: true},
      );
      expect(
        hasChatPermission(
          grantingChat,
          memberWith(roleId: 5, overrides: {ChatPermissions.messageSend: false}),
          ChatPermissions.messageSend,
        ),
        isFalse,
      );
    });

    test('a banned member is denied even with an explicit grant', () {
      final chat = chatWith(permissions: {ChatPermissions.messageSend: true});
      final banned = memberWith(
        roleId: 1,
        isBanned: true,
        overrides: {ChatPermissions.messageSend: true},
      );

      expect(
        hasChatPermission(chat, banned, ChatPermissions.messageSend),
        isFalse,
      );
    });
  });

  group('canSendMessage', () {
    test('admin_only requires message:send_admin_only, not message:send', () {
      final chat = chatWith(adminOnly: true);

      // A plain member holds `message:send` but not the admin-only variant.
      expect(canSendMessage(chat, memberWith(roleId: 5)), isFalse);
      // An editor holds both.
      expect(canSendMessage(chat, memberWith(roleId: 3)), isTrue);
      expect(canSendMessage(chat, memberWith(roleId: 2)), isTrue);
    });

    test('a muted member cannot post regardless of role', () {
      final chat = chatWith();
      expect(canSendMessage(chat, memberWith(roleId: 1, isMuted: true)), isFalse);
    });
  });

  group('canEditMessage / canDeleteMessage', () {
    test('only the author may edit, whatever their role', () {
      final me = memberWith(userId: 2, roleId: 1);
      expect(canEditMessage(me, 2), isTrue);
      // No §9.1 permission grants editing another person's message.
      expect(canEditMessage(me, 3), isFalse);
    });

    test('a muted author may not edit', () {
      expect(canEditMessage(memberWith(userId: 2, roleId: 1, isMuted: true), 2),
          isFalse);
    });

    test('anyone may delete their own message', () {
      final chat = chatWith();
      final me = memberWith(userId: 2, roleId: 5);
      expect(canDeleteMessage(chat, me, 2), isTrue);
      expect(canDeleteMessage(chat, me, 3), isFalse);
    });

    test("message:delete allows removing someone else's", () {
      final chat = chatWith();
      expect(canDeleteMessage(chat, memberWith(userId: 2, roleId: 3), 7), isTrue);
    });
  });

  group('canModerate', () {
    test('nobody moderates themselves', () {
      final me = memberWith(userId: 2, roleId: 1);
      expect(canModerate(me, me), isFalse);
    });

    test('the owner is untouchable even by an admin', () {
      final admin = memberWith(userId: 2, roleId: 2);
      final owner = memberWith(userId: 1, roleId: 1);
      expect(canModerate(admin, owner), isFalse);
    });

    test('an admin may moderate an ordinary member', () {
      final admin = memberWith(userId: 2, roleId: 2);
      final target = memberWith(userId: 3, roleId: 5);
      expect(canModerate(admin, target), isTrue);
    });
  });
}
