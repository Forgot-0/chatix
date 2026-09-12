import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/message_actions.dart';

/// The long-press menu is built from rights, not from roles read by eye. The
/// server resolves member override, then chat override, then the role matrix
/// (api-docs §8.1); these tests pin the menu to that same answer.
void main() {
  const me = 7;
  const someoneElse = 42;

  MessageEntity message({
    int? authorId = someoneElse,
    String? content = 'hello',
    MessageType type = MessageType.text,
  }) => MessageEntity(
    id: 'm1',
    chatId: 'c',
    seq: 1,
    authorId: authorId,
    type: type,
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime(2026, 1, 1, 12),
    attachments: const [],
  );

  ChatMemberEntity member({
    ChatRole role = ChatRole.member,
    bool isMuted = false,
    bool isBanned = false,
    Map<String, bool> overrides = const {},
  }) => ChatMemberEntity(
    userId: me,
    roleId: role.id,
    isMuted: isMuted,
    isBanned: isBanned,
    permissionsOverrides: overrides,
  );

  ChatEntity chat({Map<String, bool> permissions = const {}}) => ChatEntity(
    id: 'c',
    seqCounter: 10,
    lastActivityAt: DateTime(2026, 1, 1),
    type: ChatType.group,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: permissions,
    createdBy: 1,
    memberCount: 3,
  );

  List<MessageAction> actionsFor({
    ChatEntity? forChat,
    ChatMemberEntity? forMe,
    MessageEntity? forMessage,
    bool canReact = true,
    bool canSelect = true,
  }) => MessageActions.of(
    chat: forChat ?? chat(),
    me: forMe ?? member(),
    message: forMessage ?? message(),
    canReact: canReact,
    canSelect: canSelect,
  );

  group('editing', () {
    test('only the author may edit, whatever else they can do', () {
      // api-docs §5.4: PATCH is author-only, with no permission-based bypass.
      expect(actionsFor(forMessage: message(authorId: me)),
          contains(MessageAction.edit));
      expect(actionsFor(forMessage: message(authorId: someoneElse)),
          isNot(contains(MessageAction.edit)));
    });

    test('an owner still cannot edit somebody else', () {
      expect(
        actionsFor(
          forMe: member(role: ChatRole.owner),
          forMessage: message(authorId: someoneElse),
        ),
        isNot(contains(MessageAction.edit)),
      );
    });

    test('a muted member cannot edit even their own', () {
      expect(
        actionsFor(
          forMe: member(isMuted: true),
          forMessage: message(authorId: me),
        ),
        isNot(contains(MessageAction.edit)),
      );
    });
  });

  group('deleting', () {
    test('the author may delete their own', () {
      expect(actionsFor(forMessage: message(authorId: me)),
          contains(MessageAction.delete));
    });

    test('a plain member may not delete somebody else', () {
      expect(actionsFor(), isNot(contains(MessageAction.delete)));
    });

    test('the message:delete right reaches other people messages', () {
      expect(
        actionsFor(forMe: member(role: ChatRole.admin)),
        contains(MessageAction.delete),
      );
    });

    test('a member override beats the chat and the role', () {
      expect(
        actionsFor(
          forChat: chat(permissions: {ChatPermissions.messageDelete: true}),
          forMe: member(
            role: ChatRole.admin,
            overrides: {ChatPermissions.messageDelete: false},
          ),
        ),
        isNot(contains(MessageAction.delete)),
      );
    });

    test('a banned member gets nothing they could act with', () {
      final actions = actionsFor(forMe: member(isBanned: true));

      expect(actions, isNot(contains(MessageAction.delete)));
      expect(actions, isNot(contains(MessageAction.reply)));
      expect(actions, isNot(contains(MessageAction.edit)));
    });
  });

  group('replying', () {
    test('needs the right to send, since a reply is a message', () {
      expect(actionsFor(), contains(MessageAction.reply));
      expect(
        actionsFor(forMe: member(isMuted: true)),
        isNot(contains(MessageAction.reply)),
      );
    });

    test('an admin-only chat lets an admin reply and a member not', () {
      final adminOnly = ChatEntity(
        id: 'c',
        seqCounter: 10,
        lastActivityAt: DateTime(2026, 1, 1),
        type: ChatType.channel,
        name: 'News',
        description: null,
        avatarS3Key: null,
        isPublic: true,
        adminOnly: true,
        slowModeSeconds: 0,
        permissions: const {},
        createdBy: 1,
        memberCount: 3,
      );

      expect(
        actionsFor(forChat: adminOnly, forMe: member(role: ChatRole.admin)),
        contains(MessageAction.reply),
      );
      expect(
        actionsFor(forChat: adminOnly, forMe: member()),
        isNot(contains(MessageAction.reply)),
      );
    });
  });

  group('always there, or never', () {
    test('forwarding and details are offered on any ordinary message', () {
      final actions = actionsFor(forMe: member(isMuted: true));

      // Forwarding is checked against the chat it lands in, not this one.
      expect(actions, contains(MessageAction.forward));
      expect(actions, contains(MessageAction.details));
    });

    test('copy appears only where there is text to copy', () {
      expect(actionsFor(), contains(MessageAction.copy));
      expect(
        actionsFor(forMessage: message(content: '')),
        isNot(contains(MessageAction.copy)),
      );
    });

    test('reacting follows what the chat allows', () {
      expect(actionsFor(canReact: false),
          isNot(contains(MessageAction.react)));
    });

    test('select is dropped once selection is already running', () {
      expect(actionsFor(canSelect: false),
          isNot(contains(MessageAction.select)));
    });

    test('pinning is never offered: no endpoint implements it', () {
      // The role matrix carries `message:pin` (api-docs §8.1) but nothing in
      // the API pins a message, so a menu item would call nothing.
      expect(
        actionsFor(forMe: member(role: ChatRole.owner)),
        everyElement(isNot(equals('pin'))),
      );
      expect(MessageAction.values.map((a) => a.name), isNot(contains('pin')));
    });
  });

  group('system messages', () {
    test('offer only what makes sense for something nobody wrote', () {
      final actions = actionsFor(
        forMe: member(role: ChatRole.owner),
        forMessage: message(type: MessageType.system, authorId: null),
      );

      expect(actions, [MessageAction.copy, MessageAction.details]);
    });
  });

  group('order', () {
    test('reads top to bottom in the order the menu draws it', () {
      final actions = actionsFor(forMessage: message(authorId: me));

      expect(actions, [
        MessageAction.reply,
        MessageAction.react,
        MessageAction.copy,
        MessageAction.forward,
        MessageAction.edit,
        MessageAction.select,
        MessageAction.delete,
        MessageAction.details,
      ]);
    });
  });
}
