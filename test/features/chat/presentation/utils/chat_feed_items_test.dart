import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_feed_items.dart';

/// The feed is flattened before it is built, so every layout decision a row
/// makes is decided here and can be asserted without a widget tree.
void main() {
  const me = 7;
  const other = 42;

  MessageEntity message({
    required int seq,
    int? authorId = other,
    DateTime? at,
    MessageType type = MessageType.text,
  }) => MessageEntity(
    id: 'm$seq',
    chatId: 'c',
    seq: seq,
    authorId: authorId,
    type: type,
    content: 'body $seq',
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: at ?? DateTime(2026, 1, 1, 12),
    attachments: const [],
  );

  List<ChatFeedItem> build({
    required List<MessageEntity> messages,
    List<String> pendingKeys = const [],
    bool canLoadMore = false,
    int? unreadAnchorSeq,
    bool isGroupChat = true,
  }) => ChatFeedBuilder.build(
    messages: messages,
    pendingKeys: pendingKeys,
    canLoadMore: canLoadMore,
    unreadAnchorSeq: unreadAnchorSeq,
    myUserId: me,
    isGroupChat: isGroupChat,
  );

  List<FeedMessageItem> messagesOf(List<ChatFeedItem> items) =>
      items.whereType<FeedMessageItem>().toList();

  group('ordering', () {
    test('rows run newest first, the way a reverse list reads them', () {
      final items = build(
        messages: [message(seq: 3), message(seq: 2), message(seq: 1)],
      );

      expect(messagesOf(items).map((item) => item.message.seq), [3, 2, 1]);
    });

    test('pending messages sit below everything, newest last sent', () {
      final items = build(
        messages: [message(seq: 1)],
        pendingKeys: ['first', 'second'],
      );

      expect(items.first, isA<FeedPendingItem>());
      expect((items[0] as FeedPendingItem).idempotencyKey, 'second');
      expect((items[1] as FeedPendingItem).idempotencyKey, 'first');
      expect(items[2], isA<FeedMessageItem>());
    });

    test('the load-more row closes the list only when there is more', () {
      expect(
        build(messages: [message(seq: 1)], canLoadMore: true).last,
        isA<FeedLoadMoreItem>(),
      );
      expect(
        build(messages: [message(seq: 1)]).whereType<FeedLoadMoreItem>(),
        isEmpty,
      );
    });

    test('keys are the message identity, not the position', () {
      final items = build(messages: [message(seq: 9)]);

      expect(items.single.key, 'message:m9');
    });
  });

  group('grouping', () {
    test('a run by one author carries the avatar on its first row only', () {
      // Oldest last: seq 1 is the head of the run, seq 3 its tail.
      final items = messagesOf(
        build(
          messages: [
            message(seq: 3, at: DateTime(2026, 1, 1, 12, 2)),
            message(seq: 2, at: DateTime(2026, 1, 1, 12, 1)),
            message(seq: 1, at: DateTime(2026, 1, 1, 12)),
          ],
        ),
      );

      expect(items.map((item) => item.startsGroup), [false, false, true]);
      expect(items.map((item) => item.showsAvatar), [false, false, true]);
      expect(items.map((item) => item.hasAvatarGutter), [true, true, true]);
    });

    test('the last row of a run is the one that carries time and ticks', () {
      final items = messagesOf(
        build(
          messages: [
            message(seq: 3, at: DateTime(2026, 1, 1, 12, 2)),
            message(seq: 2, at: DateTime(2026, 1, 1, 12, 1)),
            message(seq: 1, at: DateTime(2026, 1, 1, 12)),
          ],
        ),
      );

      expect(items.map((item) => item.endsGroup), [true, false, false]);
    });

    test('a pause past five minutes opens a new run', () {
      final items = messagesOf(
        build(
          messages: [
            message(seq: 2, at: DateTime(2026, 1, 1, 12, 6)),
            message(seq: 1, at: DateTime(2026, 1, 1, 12)),
          ],
        ),
      );

      expect(items.every((item) => item.startsGroup), isTrue);
      expect(items.every((item) => item.endsGroup), isTrue);
    });

    test('my own messages get no gutter: nothing sits beside them', () {
      final items = messagesOf(
        build(messages: [message(seq: 1, authorId: me)]),
      );

      expect(items.single.isMine, isTrue);
      expect(items.single.hasAvatarGutter, isFalse);
      expect(items.single.showsAvatar, isFalse);
    });

    test('a direct chat has no gutter at all — the header names the peer', () {
      final items = messagesOf(
        build(messages: [message(seq: 1)], isGroupChat: false),
      );

      expect(items.single.hasAvatarGutter, isFalse);
    });
  });

  group('date separators', () {
    test('one per calendar day, on the first message of that day', () {
      final items = messagesOf(
        build(
          messages: [
            message(seq: 3, at: DateTime(2026, 1, 2, 9)),
            message(seq: 2, at: DateTime(2026, 1, 1, 18)),
            message(seq: 1, at: DateTime(2026, 1, 1, 9)),
          ],
        ),
      );

      expect(items.map((item) => item.showsDate), [true, false, true]);
    });

    test('the oldest loaded row claims no day while history is unfetched', () {
      final items = messagesOf(
        build(messages: [message(seq: 5)], canLoadMore: true),
      );

      expect(items.single.showsDate, isFalse);
    });

    test('dayAt walks down to the nearest message row', () {
      final items = build(
        messages: [message(seq: 1, at: DateTime(2026, 3, 4, 23))],
        canLoadMore: true,
      );

      // The last index is the load-more spinner, which belongs to the day of
      // the block under it.
      expect(
        ChatFeedBuilder.dayAt(items, items.length - 1),
        DateTime(2026, 3, 4),
      );
      expect(ChatFeedBuilder.dayAt(const [], 0), isNull);
    });
  });

  group('unread divider', () {
    test('fires once, on the first message past the frozen cursor', () {
      final items = messagesOf(
        build(
          messages: [message(seq: 12), message(seq: 11), message(seq: 10)],
          unreadAnchorSeq: 10,
        ),
      );

      expect(items.map((item) => item.showsUnread), [false, true, false]);
      expect(ChatFeedBuilder.unreadIndexOf(items), 1);
    });

    test('a cursor beyond the window draws nothing rather than guessing', () {
      // Every loaded message is newer than the cursor and more history is
      // waiting, so the real boundary is above what is loaded.
      final items = build(
        messages: [message(seq: 40), message(seq: 39)],
        unreadAnchorSeq: 10,
        canLoadMore: true,
      );

      expect(ChatFeedBuilder.unreadIndexOf(items), isNull);
    });

    test('with nothing left to load the oldest row can open the block', () {
      final items = build(
        messages: [message(seq: 40), message(seq: 39)],
        unreadAnchorSeq: 10,
      );

      expect(ChatFeedBuilder.unreadIndexOf(items), 1);
    });

    test('no cursor means no divider', () {
      final items = build(messages: [message(seq: 2), message(seq: 1)]);

      expect(ChatFeedBuilder.unreadIndexOf(items), isNull);
    });
  });

  group('countNewerThan', () {
    final window = [
      message(seq: 5),
      message(seq: 4, authorId: me),
      message(seq: 3),
      message(seq: 2),
      message(seq: 1),
    ];

    test('counts what sits below the furthest row seen', () {
      expect(
        ChatFeedBuilder.countNewerThan(window, seenSeq: 2, myUserId: me),
        2,
      );
    });

    test('my own messages are never news to me', () {
      expect(
        ChatFeedBuilder.countNewerThan(window, seenSeq: 3, myUserId: me),
        1,
      );
    });

    test('nothing seen yet owes no badge', () {
      expect(
        ChatFeedBuilder.countNewerThan(window, seenSeq: null, myUserId: me),
        0,
      );
    });

    test('caught up counts nothing', () {
      expect(
        ChatFeedBuilder.countNewerThan(window, seenSeq: 5, myUserId: me),
        0,
      );
    });
  });
}
