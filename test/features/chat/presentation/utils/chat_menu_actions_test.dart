import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_menu_actions.dart';

/// The chat's "⋮": nothing on it that the server would refuse.
void main() {
  const me = 7;
  const someoneElse = 42;

  ChatEntity chat(
    ChatType type, {
    int createdBy = someoneElse,
    Map<String, bool> permissions = const {},
    ChatStateEntity? state,
  }) => ChatEntity(
    id: 'c1',
    seqCounter: 1,
    lastActivityAt: null,
    type: type,
    name: type == ChatType.direct ? null : 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: permissions,
    createdBy: createdBy,
    memberCount: 2,
    state: state,
  );

  ChatMemberEntity member(
    ChatRole role, {
    Map<String, bool> overrides = const {},
  }) => ChatMemberEntity(
    userId: me,
    roleId: role.id,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: overrides,
  );

  const everyday = [
    ChatMenuAction.search,
    ChatMenuAction.mute,
    ChatMenuAction.pin,
    ChatMenuAction.archive,
    ChatMenuAction.selectMessages,
  ];

  group('a direct chat', () {
    test('the side that did not create it can leave it', () {
      expect(
        chatMenuActionsFor(chat(ChatType.direct), member(ChatRole.direct)),
        [...everyday, ChatMenuAction.leave],
      );
    });

    test('its creator has no way out to offer (api-docs §5.2, §8.1)', () {
      expect(
        chatMenuActionsFor(
          chat(ChatType.direct, createdBy: me),
          member(ChatRole.direct),
        ),
        everyday,
      );
    });

    test('is deleted only by whoever an override lets delete it', () {
      expect(
        chatMenuActionsFor(
          chat(ChatType.direct, createdBy: me),
          member(ChatRole.direct, overrides: {'chat:delete': true}),
        ),
        [...everyday, ChatMenuAction.delete],
      );
    });

    test('has nothing to manage, though `direct` holds chat:update', () {
      expect(
        chatMenuActionsFor(chat(ChatType.direct), member(ChatRole.direct)),
        isNot(contains(ChatMenuAction.manage)),
      );
    });
  });

  group('a group', () {
    test('a member can leave it and nothing more', () {
      expect(
        chatMenuActionsFor(chat(ChatType.group), member(ChatRole.member)),
        [...everyday, ChatMenuAction.leave],
      );
    });

    test('an admin manages it, and leaves it', () {
      expect(chatMenuActionsFor(chat(ChatType.group), member(ChatRole.admin)), [
        ...everyday,
        ChatMenuAction.manage,
        ChatMenuAction.leave,
      ]);
    });

    test('its creating owner manages it and can only delete it', () {
      expect(
        chatMenuActionsFor(
          chat(ChatType.supergroup, createdBy: me),
          member(ChatRole.owner),
        ),
        [...everyday, ChatMenuAction.manage, ChatMenuAction.delete],
      );
    });
  });

  test('a channel subscriber can leave, not manage', () {
    expect(
      chatMenuActionsFor(chat(ChatType.channel), member(ChatRole.viewer)),
      [...everyday, ChatMenuAction.leave],
    );
  });

  test('the reader\'s own state turns each switch the other way', () {
    const state = ChatStateEntity(
      isPinned: true,
      isArchived: true,
      isMutedByMe: true,
    );

    expect(
      chatMenuActionsFor(
        chat(ChatType.group),
        member(ChatRole.member),
        state: state,
      ),
      [
        ChatMenuAction.search,
        ChatMenuAction.unmute,
        ChatMenuAction.unpin,
        ChatMenuAction.unarchive,
        ChatMenuAction.selectMessages,
        ChatMenuAction.leave,
      ],
    );
  });

  test('the row\'s state is used when no other is given', () {
    final actions = chatMenuActionsFor(
      chat(ChatType.group, state: const ChatStateEntity(isMutedByMe: true)),
      member(ChatRole.member),
    );

    expect(actions, contains(ChatMenuAction.unmute));
    expect(actions, isNot(contains(ChatMenuAction.mute)));
  });

  test('without a membership there is nothing personal to switch', () {
    expect(chatMenuActionsFor(chat(ChatType.group), null), [
      ChatMenuAction.search,
      ChatMenuAction.selectMessages,
    ]);
  });

  test('only leaving and deleting count as destructive', () {
    expect(ChatMenuAction.values.where((action) => action.isDestructive), [
      ChatMenuAction.leave,
      ChatMenuAction.delete,
    ]);
  });

  group('the call button', () {
    test('is there for a person and for a group', () {
      expect(
        chatCallAvailable(chat(ChatType.direct), member(ChatRole.direct)),
        isTrue,
      );
      expect(
        chatCallAvailable(chat(ChatType.group), member(ChatRole.member)),
        isTrue,
      );
    });

    test('is not there for a channel, whatever the role says', () {
      expect(
        chatCallAvailable(chat(ChatType.channel), member(ChatRole.owner)),
        isFalse,
      );
    });

    test('follows a chat that switched calls off', () {
      expect(
        chatCallAvailable(
          chat(ChatType.group, permissions: {'call:join': false}),
          member(ChatRole.member),
        ),
        isFalse,
      );
    });
  });
}
