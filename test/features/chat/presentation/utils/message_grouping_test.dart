import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/message_grouping.dart';

void main() {
  const me = 7;
  const other = 42;

  MessageEntity message({
    int authorId = other,
    int seq = 1,
    DateTime? at,
    MessageType type = MessageType.text,
  }) => MessageEntity(
    id: 'm$seq',
    chatId: 'c',
    seq: seq,
    authorId: authorId,
    type: type,
    content: 'x',
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: at ?? DateTime(2026, 1, 1, 12),
    attachments: const [],
  );

  group('startsGroup', () {
    test('the very first message always starts a run', () {
      expect(MessageGrouping.startsGroup(null, message()), isTrue);
    });

    test('same author within the window continues the run', () {
      final first = message(seq: 1, at: DateTime(2026, 1, 1, 12));
      final second = message(seq: 2, at: DateTime(2026, 1, 1, 12, 3));

      expect(MessageGrouping.startsGroup(first, second), isFalse);
    });

    test('a different author breaks the run', () {
      final first = message(authorId: other, seq: 1);
      final second = message(
        authorId: me,
        seq: 2,
        at: DateTime(2026, 1, 1, 12, 1),
      );

      expect(MessageGrouping.startsGroup(first, second), isTrue);
    });

    test('a pause longer than the window breaks the run', () {
      final first = message(seq: 1, at: DateTime(2026, 1, 1, 12));
      final later = message(seq: 2, at: DateTime(2026, 1, 1, 12, 6));

      expect(MessageGrouping.startsGroup(first, later), isTrue);
    });

    test('exactly at the window is still one run', () {
      final first = message(seq: 1, at: DateTime(2026, 1, 1, 12));
      final edge = message(seq: 2, at: DateTime(2026, 1, 1, 12, 5));

      expect(MessageGrouping.startsGroup(first, edge), isFalse);
    });

    test('crossing midnight breaks the run even seconds apart', () {
      // Local times on purpose: the separator follows the reader's calendar
      // day, so that is the boundary the rule has to honour.
      final before = message(seq: 1, at: DateTime(2026, 1, 1, 23, 59, 59));
      final after = message(seq: 2, at: DateTime(2026, 1, 2, 0, 0, 1));

      expect(MessageGrouping.startsGroup(before, after), isTrue);
    });

    test('a system message never joins a run on either side', () {
      final normal = message(seq: 1);
      final system = message(
        seq: 2,
        type: MessageType.system,
        at: DateTime(2026, 1, 1, 12, 1),
      );
      final after = message(seq: 3, at: DateTime(2026, 1, 1, 12, 2));

      expect(MessageGrouping.startsGroup(normal, system), isTrue);
      expect(MessageGrouping.startsGroup(system, after), isTrue);
    });
  });

  group('sameDay', () {
    test('the same calendar day matches', () {
      expect(
        MessageGrouping.sameDay(
          DateTime(2026, 3, 4, 1),
          DateTime(2026, 3, 4, 23),
        ),
        isTrue,
      );
    });

    test('adjacent days do not', () {
      expect(
        MessageGrouping.sameDay(
          DateTime(2026, 3, 4, 23),
          DateTime(2026, 3, 5, 0),
        ),
        isFalse,
      );
    });
  });

  group('startsUnread', () {
    test('marks the first message past last_read_message_seq', () {
      expect(
        MessageGrouping.startsUnread(
          lastReadSeq: 10,
          older: message(seq: 10),
          current: message(seq: 11),
          myUserId: me,
        ),
        isTrue,
      );
    });

    test('only the crossing gets the divider, not every unread message', () {
      expect(
        MessageGrouping.startsUnread(
          lastReadSeq: 10,
          older: message(seq: 11),
          current: message(seq: 12),
          myUserId: me,
        ),
        isFalse,
      );
    });

    test('my own message never opens the unread block', () {
      expect(
        MessageGrouping.startsUnread(
          lastReadSeq: 10,
          older: message(seq: 10),
          current: message(authorId: me, seq: 11),
          myUserId: me,
        ),
        isFalse,
      );
    });

    test('a read message is never the boundary', () {
      expect(
        MessageGrouping.startsUnread(
          lastReadSeq: 10,
          older: message(seq: 8),
          current: message(seq: 9),
          myUserId: me,
        ),
        isFalse,
      );
    });

    test('no read marker at all means no divider', () {
      for (final seq in [null, 0]) {
        expect(
          MessageGrouping.startsUnread(
            lastReadSeq: seq,
            older: null,
            current: message(seq: 5),
            myUserId: me,
          ),
          isFalse,
          reason: 'lastReadSeq=$seq',
        );
      }
    });

    test('the oldest loaded message can open the block', () {
      expect(
        MessageGrouping.startsUnread(
          lastReadSeq: 3,
          older: null,
          current: message(seq: 9),
          myUserId: me,
        ),
        isTrue,
      );
    });
  });
}
