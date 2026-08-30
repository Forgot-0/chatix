import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/core/websocket/ws_event_parser.dart';

/// Unit tests for the §7.4 frame decoder.
///
/// **No socket, no server, no timers** — [parseWsEvent]/[parseWsFrame] are pure
/// functions, which is the reason they were factored out of
/// `ChatSocketService`. Everything the protocol can get wrong (a domain event
/// missing its `chat`/`message` payload, the `payload`-less `ws.ping`, the two
/// meanings of `ws.error`) is decidable from a JSON literal.
///
/// Fixtures are written as the docs write them — snake_case, full envelope —
/// so a mismatch between this file and api-docs §7.4 is visible by eye.
void main() {
  /// The §7.4 domain envelope with [payload] slotted in.
  Map<String, dynamic> envelope(
    String type, {
    String? chatId = '550e8400-e29b-41d4-a716-446655440000',
    Map<String, dynamic> payload = const {},
    String? eventName,
    String? eventId,
    String ts = '2026-01-15T10:30:00Z',
    int? seq,
  }) {
    return {
      'type': type,
      'event_name': ?eventName,
      'event_id': ?eventId,
      'chat_id': chatId,
      'payload': payload,
      'ts': ts,
      'seq': ?seq,
    };
  }

  const chatId = '550e8400-e29b-41d4-a716-446655440000';

  /// A minimal `chat`/`message` `MessagePayloadWS` payload (api-docs §7.4,
  /// revised). The parser only checks these are *maps* — decoding their
  /// fields into `ChatModel`/`MessageModel` is the feature layer's job, tested
  /// separately — so the fixtures stay minimal rather than full DTOs.
  Map<String, dynamic> chatMessagePayload({
    Map<String, dynamic> chat = const {'id': chatId, 'name': 'Team'},
    Map<String, dynamic> message = const {'id': 'm1', 'seq': 1},
  }) => {'chat': chat, 'message': message};

  group('the generic chat/message payload (§7.4, revised)', () {
    test('new_message decodes chat and message as raw maps', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          eventName: 'chats.message.sent',
          eventId: 'evt-1',
          payload: chatMessagePayload(
            message: const {
              'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
              'seq': 42,
              'author_id': 7,
              'type': 'text',
              'content': 'hi',
            },
          ),
        ),
      );

      expect(event, isA<NewMessage>());
      final message = event as NewMessage;
      expect(message.chatId, chatId);
      expect(message.chat, {'id': chatId, 'name': 'Team'});
      expect(message.message['id'], 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
      expect(message.message['content'], 'hi');
      expect(message.messageId, 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
      expect(message.messageSeq, 42);
      expect(message.eventName, 'chats.message.sent');
      expect(message.eventId, 'evt-1');
      expect(message.ts, DateTime.parse('2026-01-15T10:30:00Z'));
    });

    test('degrades to Unknown without a chat_id', () {
      final event = parseWsEvent(
        envelope('new_message', chatId: null, payload: chatMessagePayload()),
      );
      expect(event, isA<WsUnknown>());
      expect(event.type, 'new_message');
    });

    test('falls back to payload.chat_id when the envelope has none', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          chatId: null,
          payload: {...chatMessagePayload(), 'chat_id': chatId},
        ),
      );
      expect((event as NewMessage).chatId, chatId);
    });

    test('degrades to Unknown without a chat object', () {
      final event = parseWsEvent(
        envelope('new_message', payload: {'message': {'id': 'm1'}}),
      );
      expect(event, isA<WsUnknown>());
    });

    test('degrades to Unknown without a message object', () {
      final event = parseWsEvent(
        envelope('new_message', payload: {'chat': {'id': chatId}}),
      );
      expect(event, isA<WsUnknown>());
    });

    test('degrades to Unknown when chat/message are the wrong type', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          payload: {'chat': 'nope', 'message': <String, dynamic>{'id': 'm1'}},
        ),
      );
      expect(event, isA<WsUnknown>());
    });

    test('every event in the family shares the same decode path', () {
      // One table-driven check that each wire type still produces its own
      // class (the sealed hierarchy — and every exhaustive `switch` over it —
      // depends on this), all through the one generic decoder.
      const cases = {
        'new_message': NewMessage,
        'message_edited': MessageEdited,
        'message_deleted': MessageDeleted,
        'messages_read': MessagesRead,
        'member_joined': MemberJoined,
        'member_left': MemberLeft,
        'member_kick': MemberKick,
        'member_banned': MemberBanned,
        'chat_created': ChatCreated,
        'chat_updated': ChatUpdated,
      };

      for (final entry in cases.entries) {
        final event = parseWsEvent(
          envelope(entry.key, payload: chatMessagePayload()),
        );
        expect(
          event.runtimeType,
          entry.value,
          reason: '${entry.key} should decode to ${entry.value}',
        );
        final chatMessageEvent = event as WSChatMessageEvent;
        expect(chatMessageEvent.chat, {'id': chatId, 'name': 'Team'});
        expect(chatMessageEvent.message, {'id': 'm1', 'seq': 1});
      }
    });
  });

  group('reaction_update (§6.7.5, revised)', () {
    test('the current short alias decodes to ReactionUpdated', () {
      final event = parseWsEvent(
        envelope('reaction_update', payload: chatMessagePayload()),
      );
      expect(event, isA<ReactionUpdated>());
      expect(event.type, 'reaction_update');
      expect((event as ReactionUpdated).messageId, 'm1');
    });

    test('the previous raw domain-event name still decodes, for an older '
        'backend build', () {
      final event = parseWsEvent(
        envelope(
          'chats.message.reaction_updated',
          payload: chatMessagePayload(),
        ),
      );
      expect(event, isA<ReactionUpdated>());
      // Normalised to the current wire value either way, so a consumer never
      // has to branch on which one it received.
      expect(event.type, ReactionUpdated.wireType);
    });

    test('degrades to Unknown without chat/message, same as its siblings', () {
      final event = parseWsEvent(envelope('reaction_update'));
      expect(event, isA<WsUnknown>());
    });
  });

  group('messageId / messageSeq getters', () {
    test('read straight from the decoded message map', () {
      final event = parseWsEvent(
        envelope(
          'message_edited',
          payload: chatMessagePayload(
            message: const {'id': 'm7', 'seq': 43, 'content': 'edited'},
          ),
        ),
      );
      final edited = event as MessageEdited;
      expect(edited.messageId, 'm7');
      expect(edited.messageSeq, 43);
    });

    test('messageSeq accepts a whole double (JS-style JSON round-trips)', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          payload: chatMessagePayload(
            message: const {'id': 'm1', 'seq': 42.0},
          ),
        ),
      );
      expect((event as NewMessage).messageSeq, 42);
    });

    test('messageSeq is null for a fractional seq rather than truncating it', () {
      // Silent truncation would advance the delivery cursor to the wrong
      // value; `null` at least fails visibly downstream.
      final event = parseWsEvent(
        envelope(
          'new_message',
          payload: chatMessagePayload(message: const {'id': 'm1', 'seq': 4.5}),
        ),
      );
      expect((event as NewMessage).messageSeq, isNull);
    });

    test('messageSeq is null for a numeric string — no coercion attempted', () {
      // Unlike the old per-field parsing, this getter reads the decoded JSON
      // directly rather than through `_asInt`'s string-tolerant coercion.
      final event = parseWsEvent(
        envelope(
          'new_message',
          payload: chatMessagePayload(message: const {'id': 'm1', 'seq': '42'}),
        ),
      );
      expect((event as NewMessage).messageSeq, isNull);
    });

    test('messageId is null when the message map has no id', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          payload: chatMessagePayload(message: const {'seq': 1}),
        ),
      );
      expect((event as NewMessage).messageId, isNull);
    });
  });

  group('chat_deleted', () {
    test('parses who deleted it', () {
      final event = parseWsEvent(
        envelope('chat_deleted', payload: {'chat_id': chatId, 'deleted_by': 1}),
      );
      // ⚠️ Not currently defined in the backend's `WSEventType` enum at all
      // (api-docs §7.4, revised) — see `ChatDeleted`'s class doc. Parsing it
      // defensively costs nothing and means the client is ready if a future
      // build does add it.
      expect(event, isA<ChatDeleted>());
      expect((event as ChatDeleted).deletedBy, 1);
    });
  });

  group('attachment_success', () {
    test('parses the confirmed upload tokens', () {
      final event = parseWsEvent(
        envelope(
          'attachment_success',
          payload: {
            'user_id': 7,
            'chat_id': chatId,
            'tokens': ['tok-1', 'tok-2'],
          },
        ),
      );

      expect(event, isA<AttachmentSuccess>());
      final success = event as AttachmentSuccess;
      expect(success.userId, 7);
      expect(success.tokens, ['tok-1', 'tok-2']);
    });

    test('yields an empty token list when the field is absent', () {
      final event = parseWsEvent(
        envelope('attachment_success', payload: {'user_id': 7}),
      );
      expect((event as AttachmentSuccess).tokens, isEmpty);
    });

    test('skips non-string token entries', () {
      final event = parseWsEvent(
        envelope(
          'attachment_success',
          payload: {
            'user_id': 7,
            'tokens': ['tok-1', 42, null, 'tok-2'],
          },
        ),
      );
      expect((event as AttachmentSuccess).tokens, ['tok-1', 'tok-2']);
    });
  });

  group('ws.ready', () {
    test('parses the heartbeat contract and reconnect hints', () {
      final event = parseWsEvent({
        'type': 'ws.ready',
        'payload': {
          'connection_id': 'conn-1',
          'gateway_id': 'gw-1',
          'heartbeat_interval': 30,
          'heartbeat_timeout': 75,
          'reconnect': {'mode': 'last_seq_per_chat', 'op': 'resume'},
        },
      });

      expect(event, isA<WsReady>());
      final ready = event as WsReady;
      expect(ready.connectionId, 'conn-1');
      expect(ready.gatewayId, 'gw-1');
      expect(ready.heartbeatInterval, 30);
      expect(ready.heartbeatTimeout, 75);
      expect(ready.reconnectMode, 'last_seq_per_chat');
      expect(ready.reconnectOp, 'resume');
    });

    test('honours non-default heartbeat values from the server', () {
      // The service must never hard-code 30/75 — this proves the values are
      // taken from the frame.
      final event = parseWsEvent({
        'type': 'ws.ready',
        'payload': {
          'connection_id': 'c',
          'gateway_id': 'g',
          'heartbeat_interval': 10,
          'heartbeat_timeout': 25,
        },
      });

      expect((event as WsReady).heartbeatInterval, 10);
      expect(event.heartbeatTimeout, 25);
    });

    test('falls back to the documented defaults when they are absent', () {
      final event = parseWsEvent({
        'type': 'ws.ready',
        'payload': {'connection_id': 'c', 'gateway_id': 'g'},
      });

      // A 0 s interval would spin the heartbeat timer; §7.2's defaults are safe.
      expect((event as WsReady).heartbeatInterval, 30);
      expect(event.heartbeatTimeout, 75);
    });
  });

  group('ws.subscribed / ws.unsubscribed', () {
    test('parses last_seq from the payload', () {
      final event = parseWsEvent({
        'type': 'ws.subscribed',
        'chat_id': chatId,
        'payload': {'last_seq': 42},
        'ts': '2026-01-15T10:30:00Z',
      });

      expect(event, isA<WsSubscribed>());
      expect((event as WsSubscribed).chatId, chatId);
      expect(event.lastSeq, 42);
    });

    test('keeps a null last_seq null — an empty chat is not seq 0', () {
      final event = parseWsEvent({
        'type': 'ws.subscribed',
        'chat_id': chatId,
        'payload': {'last_seq': null},
      });
      expect((event as WsSubscribed).lastSeq, isNull);
    });

    test('parses ws.unsubscribed with its empty payload', () {
      final event = parseWsEvent({
        'type': 'ws.unsubscribed',
        'chat_id': chatId,
        'payload': <String, dynamic>{},
        'ts': '2026-01-15T10:30:00Z',
      });

      expect(event, isA<WsUnsubscribed>());
      expect((event as WsUnsubscribed).chatId, chatId);
    });
  });

  group('ws.history', () {
    test('keeps full MessageDTOs as raw maps for the feature layer to decode', () {
      final event = parseWsEvent({
        'type': 'ws.history',
        'chat_id': chatId,
        'payload': {
          'after_seq': 40,
          'messages': [
            {'id': 'm1', 'chat_id': chatId, 'seq': 41, 'content': 'hi'},
            {'id': 'm2', 'chat_id': chatId, 'seq': 42, 'content': 'there'},
          ],
          'has_more': true,
          'next_last_seq': 42,
        },
        'ts': '2026-01-15T10:30:00Z',
      });

      expect(event, isA<WsHistory>());
      final history = event as WsHistory;
      expect(history.afterSeq, 40);
      expect(history.messages, hasLength(2));
      // Unlike new_message, this frame really does carry content (§7.4).
      expect(history.messages.first['content'], 'hi');
      expect(history.hasMore, isTrue);
      expect(history.nextLastSeq, 42);
    });

    test('yields an empty batch rather than failing when messages is absent', () {
      final event = parseWsEvent({
        'type': 'ws.history',
        'chat_id': chatId,
        'payload': {'after_seq': 40, 'has_more': false},
      });

      expect((event as WsHistory).messages, isEmpty);
      expect(event.hasMore, isFalse);
      expect(event.nextLastSeq, isNull);
    });

    test('skips non-object entries but keeps the rest of the batch', () {
      final event = parseWsEvent({
        'type': 'ws.history',
        'chat_id': chatId,
        'payload': {
          'after_seq': 1,
          'messages': [
            {'id': 'm1'},
            'not-an-object',
            {'id': 'm2'},
          ],
        },
      });

      expect((event as WsHistory).messages, hasLength(2));
    });
  });

  group('ws.ping / ws.pong', () {
    test('ws.ping reads connection_id from the TOP LEVEL — it has no payload', () {
      // §7.4's documented shape exception; reaching into `payload` here would
      // throw on every heartbeat.
      final event = parseWsEvent({
        'type': 'ws.ping',
        'connection_id': 'conn-1',
        'ts': '2026-01-15T10:30:00Z',
      });

      expect(event, isA<WsPing>());
      final ping = event as WsPing;
      expect(ping.connectionId, 'conn-1');
      expect(ping.ts, DateTime.parse('2026-01-15T10:30:00Z'));
    });

    test('ws.pong parses from its minimal frame', () {
      final event = parseWsEvent({'type': 'ws.pong', 'payload': <String, dynamic>{}});
      expect(event, isA<WsPong>());
    });
  });

  group('ws.error', () {
    test('BAD_COMMAND becomes WsErrorBadCommand with code and detail', () {
      // §7.4: code/detail at the top level, no payload wrapper.
      final event = parseWsEvent({
        'type': 'ws.error',
        'code': 'BAD_COMMAND',
        'detail': 'unknown op "subscribee"',
        'ts': '2026-01-15T10:30:00Z',
      });

      expect(event, isA<WsErrorBadCommand>());
      final error = event as WsErrorBadCommand;
      expect(error.code, 'BAD_COMMAND');
      expect(error.detail, 'unknown op "subscribee"');
      expect(error.ts, DateTime.parse('2026-01-15T10:30:00Z'));
    });

    test('BAD_FRAME is also a bad-command error', () {
      final event = parseWsEvent({
        'type': 'ws.error',
        'code': 'BAD_FRAME',
        'detail': 'invalid json',
      });
      expect(event, isA<WsErrorBadCommand>());
      expect((event as WsErrorBadCommand).code, 'BAD_FRAME');
    });

    test('NOT_CHAT_MEMBER becomes its own type, with ts and no detail', () {
      // A different class because it demands a different reaction: stop
      // retrying that chat, rather than "fix the client".
      final event = parseWsEvent({
        'type': 'ws.error',
        'code': 'NOT_CHAT_MEMBER',
        'ts': '2026-01-15T10:30:00Z',
      });

      expect(event, isA<WsErrorNotChatMember>());
      final error = event as WsErrorNotChatMember;
      expect(error.code, 'NOT_CHAT_MEMBER');
      expect(error.ts, DateTime.parse('2026-01-15T10:30:00Z'));
      expect(error.detail, isNull);
    });

    test('the two ws.error codes never decode to the same type', () {
      final bad = parseWsEvent({'type': 'ws.error', 'code': 'BAD_COMMAND', 'detail': 'x'});
      final notMember = parseWsEvent({'type': 'ws.error', 'code': 'NOT_CHAT_MEMBER'});

      expect(bad, isA<WsErrorBadCommand>());
      expect(bad, isNot(isA<WsErrorNotChatMember>()));
      expect(notMember, isA<WsErrorNotChatMember>());
      expect(notMember, isNot(isA<WsErrorBadCommand>()));
    });

    test('an undocumented code still surfaces as an error, not Unknown', () {
      final event = parseWsEvent({
        'type': 'ws.error',
        'code': 'SOMETHING_NEW',
        'detail': 'd',
      });
      expect(event, isA<WsErrorBadCommand>());
      expect((event as WsErrorBadCommand).code, 'SOMETHING_NEW');
    });

    test('a codeless ws.error degrades to Unknown — it says nothing', () {
      final event = parseWsEvent({'type': 'ws.error', 'detail': 'no code'});
      expect(event, isA<WsUnknown>());
    });

    test('BAD_COMMAND with no detail yields an empty string, not a crash', () {
      final event = parseWsEvent({'type': 'ws.error', 'code': 'BAD_COMMAND'});
      expect((event as WsErrorBadCommand).detail, isEmpty);
    });
  });

  group('declared-but-never-published events (§7.4)', () {
    test('typing and call types are recognised as inert, not unknown', () {
      for (final type in [
        'typing_start',
        'typing_stop',
        'call_started',
        'call_ended',
        'call_joined',
        'call_left',
      ]) {
        final event = parseWsEvent(envelope(type, payload: {'user_id': 1}));
        expect(
          event,
          isA<WsUnimplementedEvent>(),
          reason: '$type should be recognised so it does not pollute unknown logs',
        );
        expect((event as WsUnimplementedEvent).type, type);
        expect(event.chatId, chatId);
      }
    });

    test('the inert set matches §7.4 exactly', () {
      expect(WsUnimplementedEvent.types, {
        'typing_start',
        'typing_stop',
        'call_started',
        'call_ended',
        'call_joined',
        'call_left',
      });
    });
  });

  group('unknown and malformed frames', () {
    test('an unrecognised type is wrapped, preserving the raw frame', () {
      // The forward-compatibility guarantee: a newer backend event must not
      // take the chat down.
      final raw = {
        'type': 'reaction_added',
        'chat_id': chatId,
        'payload': {'emoji': '👍'},
      };

      final event = parseWsEvent(raw);
      expect(event, isA<WsUnknown>());
      final unknown = event as WsUnknown;
      expect(unknown.type, 'reaction_added');
      // Kept verbatim so a log line is enough to implement it later.
      expect(unknown.raw, raw);
    });

    test('a frame with no type is wrapped as <missing>', () {
      final event = parseWsEvent({'chat_id': chatId, 'payload': {}});
      expect(event, isA<WsUnknown>());
      expect(event.type, '<missing>');
    });

    test('a non-string type is wrapped rather than crashing', () {
      final event = parseWsEvent({'type': 42});
      expect(event, isA<WsUnknown>());
      expect(event.type, '<missing>');
    });

    test('every documented type decodes without throwing', () {
      // The hard requirement: the parser runs inside the socket's listen
      // callback, where one exception ends all live updates for the session.
      const types = [
        'new_message', 'message_edited', 'message_deleted', 'messages_read',
        'member_joined', 'member_left', 'member_kick', 'member_banned',
        'chat_created', 'chat_updated', 'attachment_success', 'chat_deleted',
        'ws.ready', 'ws.subscribed', 'ws.unsubscribed', 'ws.history',
        'ws.pong', 'ws.ping', 'ws.error',
      ];

      for (final type in types) {
        // Deliberately empty payloads — the worst case a server could send.
        expect(
          () => parseWsEvent({'type': type, 'payload': <String, dynamic>{}}),
          returnsNormally,
          reason: '$type must never throw, even with an empty payload',
        );
      }
    });

    test('a mistyped payload never throws', () {
      for (final payload in [null, 'string', 42, <int>[1, 2]]) {
        expect(
          () => parseWsEvent({'type': 'new_message', 'payload': payload}),
          returnsNormally,
        );
      }
    });

    test('an unparseable ts costs the field, not the event', () {
      final event = parseWsEvent({
        'type': 'new_message',
        'chat_id': chatId,
        'payload': chatMessagePayload(),
        'ts': 'not-a-date',
      });

      expect(event, isA<NewMessage>());
      expect((event as NewMessage).ts, isNull);
    });
  });

  group('parseWsFrame — transport level', () {
    test('decodes a JSON text frame, the form the socket delivers', () {
      final frame = jsonEncode({
        'type': 'new_message',
        'chat_id': chatId,
        'payload': chatMessagePayload(
          message: const {'id': 'm1', 'seq': 7, 'type': 'text'},
        ),
        'ts': '2026-01-15T10:30:00Z',
      });

      final event = parseWsFrame(frame);
      expect(event, isA<NewMessage>());
      expect((event as NewMessage).messageSeq, 7);
    });

    test('decodes a UTF-8 binary frame instead of rejecting it', () {
      // Not part of §7 — defends against a proxy reframing text as binary.
      final bytes = utf8.encode(
        jsonEncode({'type': 'ws.pong', 'payload': <String, dynamic>{}}),
      );
      expect(parseWsFrame(bytes), isA<WsPong>());
    });

    test('malformed JSON degrades to Unknown instead of killing the stream', () {
      final event = parseWsFrame('{not json at all');
      expect(event, isA<WsUnknown>());
      expect(event.type, '<malformed>');
    });

    test('a JSON array (not an object) degrades to Unknown', () {
      final event = parseWsFrame('[1,2,3]');
      expect(event, isA<WsUnknown>());
      expect(event.type, '<malformed>');
    });

    test('an unexpected runtime type degrades to Unknown', () {
      expect(parseWsFrame(42).type, '<invalid>');
      expect(parseWsFrame(null).type, '<invalid>');
    });

    test('never throws, whatever it is handed', () {
      for (final frame in <dynamic>[
        '',
        '   ',
        'null',
        '{}',
        '{"type":null}',
        <int>[0xFF, 0xFE],
        3.14,
        true,
      ]) {
        expect(
          () => parseWsFrame(frame),
          returnsNormally,
          reason: 'parseWsFrame must be total — it runs inside listen()',
        );
      }
    });
  });

  group('event equality', () {
    test('identical frames produce equal events, so merges can dedupe', () {
      final raw = envelope(
        'new_message',
        payload: chatMessagePayload(
          message: const {'id': 'm1', 'seq': 1, 'type': 'text'},
        ),
      );
      expect(parseWsEvent(raw), equals(parseWsEvent(Map.of(raw))));
    });

    test('a differing seq produces unequal events', () {
      final a = parseWsEvent(
        envelope(
          'new_message',
          payload: chatMessagePayload(message: const {'id': 'm1', 'seq': 1}),
        ),
      );
      final b = parseWsEvent(
        envelope(
          'new_message',
          payload: chatMessagePayload(message: const {'id': 'm1', 'seq': 2}),
        ),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
