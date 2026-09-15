import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_window.dart';

/// The rules that turn three sources into one list: what the cache had, what
/// `GET /messages/` answered, and what the socket pushed (api-docs §5.4,
/// §6.4). Everything here is pure, so the cases that are awkward to arrange
/// against a real server are one function call away.
void main() {
  MessageEntity message(
    int seq, {
    String? id,
    String content = 'hello',
    bool isEdited = false,
  }) => MessageEntity(
    id: id ?? 'm$seq',
    chatId: 'c1',
    seq: seq,
    authorId: 42,
    type: MessageType.text,
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: isEdited,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  group('merge', () {
    test('runs newest first whatever order the sources were in', () {
      final merged = MessageWindow.merge(
        [message(3), message(1)],
        [message(2), message(5)],
      );

      expect(merged.map((m) => m.seq), [5, 3, 2, 1]);
    });

    test('the later source wins on the same message', () {
      // The cached copy and the socket's copy of one message: the socket
      // knows about the edit, the cache does not.
      final merged = MessageWindow.merge(
        [message(4, content: 'before')],
        [message(4, content: 'after', isEdited: true)],
      );

      expect(merged, hasLength(1));
      expect(merged.single.content, 'after');
      expect(merged.single.isEdited, isTrue);
    });

    test('a redelivered message lands once', () {
      // Delivery is at-least-once (api-docs §6.4), so the same frame can be
      // merged twice; two copies of one message is not a thing the feed can
      // draw.
      final merged = MessageWindow.merge(
        [message(7)],
        [message(7), message(7)],
      );

      expect(merged, hasLength(1));
    });

    test('a seq is one message, whatever id arrives under it', () {
      // `seq` is unique within a chat, so two ids on one seq means the
      // locally held copy was wrong about which message that was.
      final merged = MessageWindow.merge(
        [message(9, id: 'stale')],
        [message(9, id: 'real')],
      );

      expect(merged.map((m) => m.id), ['real']);
    });

    test('an empty source changes nothing', () {
      final merged = MessageWindow.merge([message(2), message(1)], const []);
      expect(merged.map((m) => m.seq), [2, 1]);
    });
  });

  group('reconcile', () {
    test('drops what the fetched page says is gone', () {
      // seq 2 was deleted while this device was away: nothing announced it,
      // it is simply not in the page the server just sent.
      final reconciled = MessageWindow.reconcile(
        [message(3), message(2), message(1)],
        [message(3), message(1)],
      );

      expect(reconciled.map((m) => m.seq), [3, 1]);
    });

    test('keeps history older than the page', () {
      // Scroll-back already loaded is not deleted just because the newest
      // page does not mention it.
      final reconciled = MessageWindow.reconcile(
        [message(10), message(4), message(3)],
        [message(10), message(9)],
      );

      expect(reconciled.map((m) => m.seq), [10, 9, 4, 3]);
    });

    test('keeps a message newer than the page', () {
      // A push that arrived while the fetch was in flight.
      final reconciled = MessageWindow.reconcile(
        [message(12), message(5)],
        [message(5), message(4)],
      );

      expect(reconciled.map((m) => m.seq), [12, 5, 4]);
    });

    test('an empty page deletes nothing', () {
      final reconciled = MessageWindow.reconcile([message(2)], const []);
      expect(reconciled.map((m) => m.seq), [2]);
    });
  });

  group('isGap', () {
    test('the next seq is not a gap', () {
      expect(MessageWindow.isGap([message(4)], message(5)), isFalse);
    });

    test('a skipped seq is', () {
      expect(MessageWindow.isGap([message(4)], message(7)), isTrue);
    });

    test('the first message of an empty screen is not', () {
      expect(MessageWindow.isGap(const [], message(900)), isFalse);
    });

    test('a message already behind us is not', () {
      // A replay of something the window already holds.
      expect(MessageWindow.isGap([message(9)], message(3)), isFalse);
    });
  });

  test('newest keeps the top of the window', () {
    final kept = MessageWindow.newest([
      message(1),
      message(5),
      message(3),
      message(4),
    ], 2);

    expect(kept.map((m) => m.seq), [5, 4]);
  });
}
