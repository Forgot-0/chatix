import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/notification/domain/entities/push_message.dart';

/// `NotificationDTO.payload` is `Record<string, unknown>` and the backend does
/// not type it (api-docs §7.2), so every one of these shapes is one the app
/// may actually be handed.
void main() {
  test('reads a flat payload', () {
    final message = PushMessage.fromPayload(const {
      'chat_id': 'c-1',
      'message_id': 'm-1',
      'message_seq': '42',
      'sender_name': 'Ada',
      'body': 'Hello',
    });

    expect(message.chatId, 'c-1');
    expect(message.messageId, 'm-1');
    expect(message.messageSeq, 42);
    expect(message.senderName, 'Ada');
    expect(message.text, 'Hello');
    expect(message.isSystem, isFalse);
  });

  test('digs the fields out of a nested payload', () {
    final message = PushMessage.fromPayload(const {
      'data': {
        'message': {'chat_id': 'c-2', 'seq': 7},
      },
    });

    expect(message.chatId, 'c-2');
    expect(message.messageSeq, 7);
  });

  test('decodes a nested object that arrived as a string', () {
    // Every value in an FCM `data` map is a string.
    final message = PushMessage.fromPayload(const {
      'payload': '{"chat_id":"c-3","message_id":"m-3"}',
    });

    expect(message.chatId, 'c-3');
    expect(message.messageId, 'm-3');
  });

  test('a top-level value is not shadowed by a nested one', () {
    final message = PushMessage.fromPayload(const {
      'chat_id': 'outer',
      'data': {'chat_id': 'inner'},
    });

    expect(message.chatId, 'outer');
  });

  test('a payload with no chat is a system notice', () {
    final message = PushMessage.fromPayload(const {
      'title': 'Your email is verified',
    });

    expect(message.isSystem, isTrue);
    expect(message.isActionable, isTrue);
    expect(message.groupKey, isNull);
  });

  test('an empty payload is not worth drawing', () {
    expect(PushMessage.fromPayload(const {}).isActionable, isFalse);
  });

  test('the string "null" is not a value', () {
    final message = PushMessage.fromPayload(const {
      'chat_id': 'c-1',
      'sender_name': 'null',
      'body': '   ',
    });

    expect(message.senderName, isNull);
    expect(message.text, isNull);
  });

  test('a seq below one is no seq at all', () {
    final message = PushMessage.fromPayload(const {
      'chat_id': 'c-1',
      'seq': '0',
    });

    expect(message.messageSeq, isNull);
  });

  test('a mention is recognised however it is spelled', () {
    for (final value in const ['true', '1', 'yes']) {
      final message = PushMessage.fromPayload({
        'chat_id': 'c-1',
        'is_mention': value,
      });
      expect(message.isMention, isTrue, reason: value);
    }

    expect(
      PushMessage.fromPayload(const {'chat_id': 'c-1'}).isMention,
      isFalse,
    );
  });

  test('chats bundle by chat, and each message keeps its own id', () {
    final first = PushMessage.fromPayload(const {
      'chat_id': 'c-1',
      'message_id': 'm-1',
    });
    final second = PushMessage.fromPayload(const {
      'chat_id': 'c-1',
      'message_id': 'm-2',
    });

    expect(first.groupKey, 'chat_c-1');
    expect(second.groupKey, first.groupKey);
    expect(first.notificationId, isNot(second.notificationId));
  });

  test('a payload with only a chat still has a stable notification id', () {
    final message = PushMessage.fromPayload(const {'chat_id': 'c-1'});

    expect(message.notificationId, 'chat_c-1');
  });

  test('reads a timestamp whether it is ISO, seconds or milliseconds', () {
    final iso = PushMessage.fromPayload(const {
      'chat_id': 'c-1',
      'created_at': '2026-09-17T10:00:00Z',
    });
    final seconds = PushMessage.fromPayload(const {
      'chat_id': 'c-1',
      'sent_at': '1789552800',
    });
    final millis = PushMessage.fromPayload(const {
      'chat_id': 'c-1',
      'timestamp': '1789552800000',
    });

    expect(iso.sentAt, DateTime.utc(2026, 9, 17, 10).toLocal());
    expect(seconds.sentAt, millis.sentAt);
  });

  test('keeps the payload it was built from, for the tap to re-read', () {
    const payload = {'chat_id': 'c-1', 'extra': 'kept'};

    expect(PushMessage.fromPayload(payload).raw, payload);
  });
}
