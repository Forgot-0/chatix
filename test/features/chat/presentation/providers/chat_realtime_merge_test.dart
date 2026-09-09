import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_realtime_merge.dart';

void main() {
  const chatId = 'a3f1c2d4-0000-4000-8000-000000000001';

  MessageEntity message({
    required String id,
    required int seq,
    int authorId = 42,
    String? content,
  }) => MessageEntity(
    id: id,
    chatId: chatId,
    seq: seq,
    authorId: authorId,
    type: MessageType.text,
    content: content ?? 'message $seq',
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 1, 1),
    attachments: const [],
  );

  ChatEntity row({
    int seqCounter = 5,
    int? unreadCount = 0,
    MessageEntity? lastMessage,
  }) => ChatEntity(
    id: chatId,
    seqCounter: seqCounter,
    lastActivityAt: DateTime.utc(2026, 1, 1),
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
    unreadCount: unreadCount,
    lastMessage: lastMessage,
  );

  group('applyNewMessageToRow — list preview (api-docs §5.2 last_message)', () {
    test('adopts the incoming message as the row preview', () {
      final incoming = message(id: 'm6', seq: 6, content: 'newest');

      final updated = ChatRealtimeMerge.applyNewMessageToRow(
        row(
          lastMessage: message(id: 'm5', seq: 5, content: 'older'),
        ),
        incoming,
        ts: DateTime.utc(2026, 1, 2),
        isOpen: false,
        isOwn: false,
      );

      expect(updated.lastMessage, incoming);
      expect(updated.lastMessage?.content, 'newest');
    });

    test('fills the preview on a row that never had one', () {
      final incoming = message(id: 'm6', seq: 6);

      final updated = ChatRealtimeMerge.applyNewMessageToRow(
        row(),
        incoming,
        ts: null,
        isOpen: false,
        isOwn: false,
      );

      expect(updated.lastMessage, incoming);
    });

    test('a REPLAYED older frame must not overwrite a newer preview', () {
      final newest = message(id: 'm9', seq: 9, content: 'newest');
      final stale = message(id: 'm2', seq: 2, content: 'stale replay');

      final updated = ChatRealtimeMerge.applyNewMessageToRow(
        row(seqCounter: 9, lastMessage: newest),
        stale,
        ts: DateTime.utc(2026, 1, 2),
        isOpen: false,
        isOwn: false,
      );

      // Delivery is at-least-once and ws.history replays out of order,
      // so an old seq may legitimately arrive after a new one.
      expect(updated.lastMessage, newest);
      expect(updated.seqCounter, 9);
    });
  });

  group('applyNewMessageToRow — counters', () {
    test('bumps unread for a foreign message in a chat that is not open', () {
      final updated = ChatRealtimeMerge.applyNewMessageToRow(
        row(unreadCount: 3),
        message(id: 'm6', seq: 6),
        ts: null,
        isOpen: false,
        isOwn: false,
      );

      expect(updated.unreadCount, 4);
    });

    test('does not bump unread while the chat is open', () {
      final updated = ChatRealtimeMerge.applyNewMessageToRow(
        row(unreadCount: 3),
        message(id: 'm6', seq: 6),
        ts: null,
        isOpen: true,
        isOwn: false,
      );

      expect(updated.unreadCount, 3);
    });

    test('does not bump unread for my own message', () {
      final updated = ChatRealtimeMerge.applyNewMessageToRow(
        row(unreadCount: 3),
        message(id: 'm6', seq: 6),
        ts: null,
        isOpen: false,
        isOwn: true,
      );

      expect(updated.unreadCount, 3);
    });

    test('still updates the preview for my own message', () {
      final mine = message(id: 'm6', seq: 6, content: 'sent by me');

      final updated = ChatRealtimeMerge.applyNewMessageToRow(
        row(),
        mine,
        ts: null,
        isOpen: true,
        isOwn: true,
      );

      expect(updated.lastMessage, mine);
    });

    test('advances seqCounter and lastActivityAt from the event ts', () {
      final ts = DateTime.utc(2026, 3, 4, 5, 6);

      final updated = ChatRealtimeMerge.applyNewMessageToRow(
        row(seqCounter: 5),
        message(id: 'm11', seq: 11),
        ts: ts,
        isOpen: false,
        isOwn: false,
      );

      expect(updated.seqCounter, 11);
      expect(updated.lastActivityAt, ts);
    });
  });
}
