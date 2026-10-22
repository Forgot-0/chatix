import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/unread_mentions.dart';

/// Unread mentions are read out of message text (api-docs §5.4 has no
/// mention entities) — so the rules for what counts are the whole feature.
void main() {
  const me = 7;

  MessageEntity message(String? content, {int seq = 5, int authorId = 9}) =>
      MessageEntity(
        id: 'm$seq',
        chatId: 'c',
        seq: seq,
        authorId: authorId,
        type: MessageType.text,
        content: content,
        replyToId: null,
        forwardedFromChatId: null,
        forwardedFromMessageId: null,
        forwardedFromAuthorId: null,
        isEdited: false,
        createdAt: DateTime.utc(2026),
      );

  ChatEntity chat({
    int unread = 0,
    int seqCounter = 10,
    int? lastReadSeq,
    MessageEntity? last,
  }) => ChatEntity(
    id: 'c',
    seqCounter: seqCounter,
    lastActivityAt: DateTime.utc(2026),
    type: ChatType.group,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: 3,
    unreadCount: unread,
    lastMessage: last,
    lastRead: lastReadSeq == null
        ? null
        : ReadDetailEntity(
            lastReadMessageSeq: lastReadSeq,
            lastReadAt: DateTime.utc(2026),
          ),
  );

  group('mentions', () {
    test('finds the handle wherever a word starts', () {
      expect(UnreadMentions.mentions('@mira hi', 'mira'), isTrue);
      expect(UnreadMentions.mentions('hi @mira', 'mira'), isTrue);
      expect(UnreadMentions.mentions('(@mira)', 'mira'), isTrue);
    });

    test('ignores case, as a handle does', () {
      expect(UnreadMentions.mentions('@Mira, look', 'mira'), isTrue);
      expect(UnreadMentions.mentions('@mira', 'MIRA'), isTrue);
    });

    test('a full stop after the handle is the sentence\'s', () {
      expect(UnreadMentions.mentions('Thanks, @mira.', 'mira'), isTrue);
    });

    test('a longer handle is somebody else', () {
      expect(UnreadMentions.mentions('@mirabel hi', 'mira'), isFalse);
      expect(UnreadMentions.mentions('@mira_k hi', 'mira'), isFalse);
      expect(UnreadMentions.mentions('@mira.k hi', 'mira'), isFalse);
    });

    test('an address or a word with @ inside is not a mention', () {
      expect(UnreadMentions.mentions('mail mira@example.com', 'mira'), isFalse);
      expect(UnreadMentions.mentions('x@mira', 'mira'), isFalse);
      expect(UnreadMentions.mentions('mira without the at', 'mira'), isFalse);
    });

    test('no text, no mention', () {
      expect(UnreadMentions.mentions(null, 'mira'), isFalse);
      expect(UnreadMentions.mentions('', 'mira'), isFalse);
    });
  });

  group('newestMentionSeq', () {
    test('picks the highest seq that mentions the reader', () {
      final seq = UnreadMentions.newestMentionSeq(
        [
          message('@mira one', seq: 3),
          message('nothing', seq: 8),
          message('@mira two', seq: 6),
        ],
        myUserId: me,
        handle: 'mira',
      );

      expect(seq, 6);
    });

    test('the reader writing their own handle does not count', () {
      final seq = UnreadMentions.newestMentionSeq(
        [message('as @mira said', authorId: me)],
        myUserId: me,
        handle: 'mira',
      );

      expect(seq, isNull);
    });

    test('skips holes in what is known', () {
      expect(
        UnreadMentions.newestMentionSeq(
          [null, message('@mira', seq: 4)],
          myUserId: me,
          handle: 'mira',
        ),
        4,
      );
    });

    test('a handle no message can name has no mentions', () {
      // Usernames may hold spaces (api-docs §3.2); the bubble cannot find
      // such a handle again, so neither does the list.
      expect(
        UnreadMentions.newestMentionSeq(
          [message('@Mira Lee hi')],
          myUserId: me,
          handle: 'Mira Lee',
        ),
        isNull,
      );
    });
  });

  group('readUpTo', () {
    test('counts back from the newest seq by the unread count', () {
      expect(UnreadMentions.readUpTo(chat(unread: 3, seqCounter: 10)), 7);
    });

    test('takes the later of that and the server\'s last_read', () {
      // A realtime patch moves the count on and leaves last_read behind.
      expect(
        UnreadMentions.readUpTo(
          chat(unread: 1, seqCounter: 20, lastReadSeq: 4),
        ),
        19,
      );
      expect(
        UnreadMentions.readUpTo(
          chat(unread: 5, seqCounter: 20, lastReadSeq: 18),
        ),
        18,
      );
    });

    test('a last message newer than the counter wins', () {
      expect(
        UnreadMentions.readUpTo(
          chat(unread: 2, seqCounter: 10, last: message('x', seq: 12)),
        ),
        10,
      );
    });
  });

  group('isUnread', () {
    test('a mention past the read position is waiting', () {
      expect(UnreadMentions.isUnread(chat(unread: 3), 9), isTrue);
    });

    test('one at or before it has been read', () {
      expect(UnreadMentions.isUnread(chat(unread: 3), 7), isFalse);
      expect(UnreadMentions.isUnread(chat(unread: 3), 2), isFalse);
    });

    test('a chat with nothing unread has no unread mention', () {
      expect(UnreadMentions.isUnread(chat(), 10), isFalse);
    });

    test('an old mention does not come back with a new message', () {
      // Read up to 10, mentioned at 6, then one new message arrives.
      expect(
        UnreadMentions.isUnread(chat(unread: 1, seqCounter: 11), 6),
        isFalse,
      );
    });

    test('no mention, nothing to say', () {
      expect(UnreadMentions.isUnread(chat(unread: 3), null), isFalse);
    });
  });
}
