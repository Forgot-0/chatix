import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_members_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';

void main() {
  const tOwner = ChatMemberEntity(
    userId: 1,
    roleId: 1,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: {},
  );

  const tMember = ChatMemberEntity(
    userId: 2,
    roleId: 5,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: {},
  );

  const tChatDetail = ChatEntity(
    id: 'a3f1c2d4-0000-4000-8000-000000000001',
    seqCounter: 9,
    lastActivityAt: null,
    type: ChatType.group,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: {},
    createdBy: 1,
    memberCount: 2,
    members: [tOwner, tMember],
  );

  const tChatListEntry = ChatEntity(
    id: 'a3f1c2d4-0000-4000-8000-000000000001',
    seqCounter: 9,
    lastActivityAt: null,
    type: ChatType.group,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: {},
    createdBy: 1,
    memberCount: 2,
    unreadCount: 0,
    me: tOwner,
  );

  group('ChatDetailState.me', () {
    test('resolves the caller from `members` when the chat has no `me`', () {
      const state = ChatDetailState(chat: tChatDetail, myUserId: 1);

      expect(state.me, tOwner);
      expect(canSendMessage(state.chat, state.me), isTrue);
      expect(
        hasChatPermission(state.chat, state.me, ChatPermissions.chatDelete),
        isTrue,
      );
    });

    test('picks the row matching MY id, not simply the first one', () {
      const state = ChatDetailState(chat: tChatDetail, myUserId: 2);

      expect(state.me, tMember);
      expect(canSendMessage(state.chat, state.me), isTrue);
      expect(
        hasChatPermission(state.chat, state.me, ChatPermissions.chatDelete),
        isFalse,
      );
    });

    test('still honours `me` when the chat came from a ChatDTO endpoint', () {
      const state = ChatDetailState(chat: tChatListEntry, myUserId: 1);

      expect(state.me, tOwner);
    });

    test('is null for a non-member previewing the chat (fail-closed)', () {
      const state = ChatDetailState(chat: tChatDetail, myUserId: 999);

      expect(state.me, isNull);
      expect(canSendMessage(state.chat, state.me), isFalse);
    });

    test('falls back to `me` when the signed-in id is not yet known', () {
      const state = ChatDetailState(chat: tChatListEntry);

      expect(state.me, tOwner);
    });

    test('survives copyWith — myUserId is not dropped', () {
      const state = ChatDetailState(chat: tChatDetail, myUserId: 1);

      final copied = state.copyWith(isLoadingMore: true);

      expect(copied.myUserId, 1);
      expect(copied.me, tOwner);
    });
  });

  group('ChatMembersState.me', () {
    test('resolves the caller from the paginated members list', () {
      const state = ChatMembersState(
        chat: tChatDetail,
        members: [tOwner, tMember],
        myUserId: 1,
      );

      expect(state.me, tOwner);
      expect(
        hasChatPermission(state.chat, state.me, ChatPermissions.memberKick),
        isTrue,
      );
    });

    test('prefers the freshest members row over the chat roster', () {
      const demoted = ChatMemberEntity(
        userId: 1,
        roleId: 6,
        isMuted: false,
        isBanned: false,
        permissionsOverrides: {},
      );
      const state = ChatMembersState(
        chat: tChatDetail,
        members: [demoted, tMember],
        myUserId: 1,
      );

      expect(state.me, demoted);
      expect(
        hasChatPermission(state.chat, state.me, ChatPermissions.memberKick),
        isFalse,
      );
    });

    test('falls back to the chat roster when my page is not loaded yet', () {
      const state = ChatMembersState(
        chat: tChatDetail,
        members: [tMember],
        myUserId: 1,
      );

      expect(state.me, tOwner);
    });

    test('a plain member is offered no moderation controls', () {
      const state = ChatMembersState(
        chat: tChatDetail,
        members: [tOwner, tMember],
        myUserId: 2,
      );

      expect(state.me, tMember);
      expect(
        hasChatPermission(state.chat, state.me, ChatPermissions.memberKick),
        isFalse,
      );
      expect(
        hasChatPermission(state.chat, state.me, ChatPermissions.roleChange),
        isFalse,
      );
    });

    test('survives copyWith — myUserId is not dropped', () {
      const state = ChatMembersState(
        chat: tChatDetail,
        members: [tOwner],
        myUserId: 1,
      );

      final copied = state.copyWith(isLoadingMore: true);

      expect(copied.myUserId, 1);
      expect(copied.me, tOwner);
    });
  });
}
