import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';

void main() {
  const myUserId = 7;
  const peerId = 9;

  final now = DateTime.utc(2026, 3, 10, 12);

  MessageEntity message({
    required int authorId,
    DateTime? createdAt,
  }) => MessageEntity(
    id: 'm-1',
    chatId: 'a',
    seq: 4,
    authorId: authorId,
    type: MessageType.text,
    content: 'hello',
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: createdAt ?? now,
  );

  ChatEntity chat({
    String id = 'a',
    ChatType type = ChatType.group,
    int unread = 0,
    MessageEntity? last,
    List<ChatMemberEntity>? members,
    int createdBy = 1,
  }) => ChatEntity(
    id: id,
    seqCounter: 4,
    lastActivityAt: now,
    type: type,
    name: 'Chat $id',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: createdBy,
    memberCount: 2,
    unreadCount: unread,
    lastMessage: last,
    members: members,
  );

  ChatRuleContext context({Set<String> pinned = const <String>{}}) =>
      ChatRuleContext(
        now: now,
        myUserId: myUserId,
        pinnedChatIds: pinned,
      );

  group('chat type rule', () {
    test('keeps the listed types and nothing else', () {
      const rule = ChatTypeRule({ChatType.group, ChatType.supergroup});

      expect(rule.evaluate(chat(), context()), isTrue);
      expect(
        rule.evaluate(chat(type: ChatType.supergroup), context()),
        isTrue,
      );
      expect(rule.evaluate(chat(type: ChatType.direct), context()), isFalse);
    });

    test('an empty set matches nothing rather than everything', () {
      const rule = ChatTypeRule(<ChatType>{});

      for (final type in ChatType.values) {
        expect(rule.evaluate(chat(type: type), context()), isFalse);
      }
    });
  });

  group('unread rule', () {
    test('reads the row\'s unread count', () {
      expect(const UnreadRule().evaluate(chat(unread: 2), context()), isTrue);
      expect(const UnreadRule().evaluate(chat(), context()), isFalse);
    });

    test('can be turned around to keep what is already read', () {
      const rule = UnreadRule(expected: false);

      expect(rule.evaluate(chat(), context()), isTrue);
      expect(rule.evaluate(chat(unread: 1), context()), isFalse);
    });
  });

  group('pinned rule', () {
    test('asks the context, since the row does not know', () {
      expect(
        const PinnedRule().evaluate(chat(), context(pinned: {'a'})),
        isTrue,
      );
      expect(const PinnedRule().evaluate(chat(), context()), isFalse);
    });

    test('turned around, it keeps everything that is not pinned', () {
      const rule = PinnedRule(expected: false);

      expect(rule.evaluate(chat(), context()), isTrue);
      expect(rule.evaluate(chat(), context(pinned: {'a'})), isFalse);
    });
  });

  group('no reply from me rule', () {
    test('a chat whose last word is mine is not waiting on me', () {
      final rule = const NoReplyFromMeRule();

      expect(
        rule.evaluate(chat(last: message(authorId: myUserId)), context()),
        isFalse,
      );
    });

    test('somebody else having the last word is enough at zero days', () {
      expect(
        const NoReplyFromMeRule().evaluate(
          chat(last: message(authorId: peerId)),
          context(),
        ),
        isTrue,
      );
    });

    test('with a waiting time it only counts once that time has passed', () {
      const rule = NoReplyFromMeRule(days: 3);

      final fresh = chat(
        last: message(
          authorId: peerId,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      );
      final stale = chat(
        last: message(
          authorId: peerId,
          createdAt: now.subtract(const Duration(days: 4)),
        ),
      );

      expect(rule.evaluate(fresh, context()), isFalse);
      expect(rule.evaluate(stale, context()), isTrue);
    });

    test('a chat with no message, or nobody signed in, stays out', () {
      expect(const NoReplyFromMeRule().evaluate(chat(), context()), isFalse);
      expect(
        const NoReplyFromMeRule().evaluate(
          chat(last: message(authorId: peerId)),
          ChatRuleContext(now: now),
        ),
        isFalse,
      );
    });
  });

  group('member rule', () {
    const rule = MemberRule(userId: peerId, label: 'Ann');

    ChatMemberEntity member(int userId) => ChatMemberEntity(
      userId: userId,
      roleId: 4,
      isMuted: false,
      isBanned: false,
      permissionsOverrides: const {},
    );

    test('finds a person in a roster the app has loaded', () {
      expect(
        rule.evaluate(chat(members: [member(peerId)]), context()),
        isTrue,
      );
    });

    test('falls back to the last sender and the chat\'s creator', () {
      expect(
        rule.evaluate(chat(last: message(authorId: peerId)), context()),
        isTrue,
      );
      expect(rule.evaluate(chat(createdBy: peerId), context()), isTrue);
    });

    test('says no when nothing on the row names that person', () {
      expect(
        rule.evaluate(chat(last: message(authorId: myUserId)), context()),
        isFalse,
      );
    });
  });

  group('a folder over its rules', () {
    final unreadGroups = ChatFolder(
      id: 'f1',
      title: 'Loud groups',
      rules: const [
        ChatTypeRule({ChatType.group}),
        UnreadRule(),
      ],
    );

    test('matching all means every rule has to hold', () {
      expect(unreadGroups.matches(chat(unread: 1), context()), isTrue);
      expect(unreadGroups.matches(chat(), context()), isFalse);
      expect(
        unreadGroups.matches(
          chat(type: ChatType.direct, unread: 1),
          context(),
        ),
        isFalse,
      );
    });

    test('matching any means one rule is enough', () {
      final either = unreadGroups.copyWith(matchMode: FolderMatchMode.any);

      expect(either.matches(chat(), context()), isTrue);
      expect(
        either.matches(chat(type: ChatType.direct, unread: 1), context()),
        isTrue,
      );
      expect(
        either.matches(chat(type: ChatType.direct), context()),
        isFalse,
      );
    });

    test('a folder with no rules keeps nothing, rather than everything', () {
      const empty = ChatFolder(id: 'f2', title: 'Empty', rules: []);

      expect(empty.matches(chat(unread: 4), context()), isFalse);
    });
  });

  group('presets', () {
    test('each one is a folder made of ordinary rules', () {
      for (final preset in FolderPreset.values) {
        final folder = ChatFolder.fromPreset(preset);

        expect(folder.rules, isNotEmpty);
        expect(folder.isPreset, isTrue);
        expect(folder.id, preset.folderId);
      }
    });

    test('personal keeps direct chats, groups keeps the two group kinds', () {
      final personal = ChatFolder.fromPreset(FolderPreset.personal);
      final groups = ChatFolder.fromPreset(FolderPreset.groups);

      expect(
        personal.matches(chat(type: ChatType.direct), context()),
        isTrue,
      );
      expect(personal.matches(chat(type: ChatType.group), context()), isFalse);

      expect(groups.matches(chat(type: ChatType.group), context()), isTrue);
      expect(
        groups.matches(chat(type: ChatType.supergroup), context()),
        isTrue,
      );
      expect(
        groups.matches(chat(type: ChatType.channel), context()),
        isFalse,
      );
    });
  });
}
