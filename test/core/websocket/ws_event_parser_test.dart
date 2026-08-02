import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/core/websocket/ws_event_parser.dart';

/// Unit tests for the §7.4 frame decoder.
///
/// **No socket, no server, no timers** — [parseWsEvent]/[parseWsFrame] are pure
/// functions, which is the reason they were factored out of
/// `ChatSocketService`. Everything the protocol can get wrong (missing content
/// in `new_message`, the `payload`-less `ws.ping`, the two meanings of
/// `ws.error`, `member_banned`'s unban case) is decidable from a JSON literal.
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

  group('new_message', () {
    test('parses ids only — §7.4 carries no message content', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          eventName: 'chats.message.sent',
          eventId: 'evt-1',
          seq: 42,
          payload: {
            'message_id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
            'seq': 42,
            'sender_id': 7,
            'message_type': 'text',
          },
        ),
      );

      expect(event, isA<NewMessage>());
      final message = event as NewMessage;
      expect(message.chatId, chatId);
      expect(message.messageId, 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
      expect(message.seq, 42);
      expect(message.senderId, 7);
      expect(message.messageType, 'text');
      expect(message.eventName, 'chats.message.sent');
      expect(message.eventId, 'evt-1');
      expect(message.ts, DateTime.parse('2026-01-15T10:30:00Z'));
    });

    test('accepts a null sender_id (system messages have no author)', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          payload: {
            'message_id': 'm1',
            'seq': 5,
            'sender_id': null,
            'message_type': 'system',
          },
        ),
      );

      expect((event as NewMessage).senderId, isNull);
      expect(event.messageType, 'system');
    });

    test('defaults message_type to "text" when absent, mirroring the backend', () {
      final event = parseWsEvent(
        envelope('new_message', payload: {'message_id': 'm1', 'seq': 5}),
      );
      expect((event as NewMessage).messageType, 'text');
    });

    test('reads seq from the envelope when the payload omits it', () {
      // §7.4: seq is duplicated at both levels, so either alone must work.
      final event = parseWsEvent(
        envelope('new_message', seq: 99, payload: {'message_id': 'm1'}),
      );
      expect((event as NewMessage).seq, 99);
    });

    test('prefers the payload seq over the envelope seq', () {
      final event = parseWsEvent(
        envelope('new_message', seq: 1, payload: {'message_id': 'm1', 'seq': 42}),
      );
      expect((event as NewMessage).seq, 42);
    });

    test('falls back to payload.chat_id when the envelope has none', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          chatId: null,
          payload: {'chat_id': chatId, 'message_id': 'm1', 'seq': 3},
        ),
      );
      expect((event as NewMessage).chatId, chatId);
    });

    test('degrades to Unknown without a message_id — nothing to fetch', () {
      final event = parseWsEvent(envelope('new_message', payload: {'seq': 5}));
      expect(event, isA<WsUnknown>());
      expect(event.type, 'new_message');
    });

    test('degrades to Unknown without a seq rather than inventing 0', () {
      // A fabricated seq would poison the resume cursor and silently skip
      // messages after the next reconnect.
      final event = parseWsEvent(
        envelope('new_message', payload: {'message_id': 'm1'}),
      );
      expect(event, isA<WsUnknown>());
    });

    test('degrades to Unknown when no chat_id can be resolved', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          chatId: null,
          payload: {'message_id': 'm1', 'seq': 1},
        ),
      );
      expect(event, isA<WsUnknown>());
    });
  });

  group('message_edited / message_deleted', () {
    test('message_edited exposes modified_by', () {
      final event = parseWsEvent(
        envelope(
          'message_edited',
          payload: {'message_id': 'm1', 'seq': 43, 'modified_by': 7},
        ),
      );

      expect(event, isA<MessageEdited>());
      final edited = event as MessageEdited;
      expect(edited.messageId, 'm1');
      expect(edited.seq, 43);
      expect(edited.modifiedBy, 7);
    });

    test('message_deleted exposes deleted_by', () {
      final event = parseWsEvent(
        envelope(
          'message_deleted',
          payload: {'message_id': 'm1', 'seq': 44, 'deleted_by': 9},
        ),
      );

      expect(event, isA<MessageDeleted>());
      final deleted = event as MessageDeleted;
      expect(deleted.messageId, 'm1');
      expect(deleted.seq, 44);
      expect(deleted.deletedBy, 9);
    });

    test('both degrade to Unknown when the message_id is missing', () {
      expect(
        parseWsEvent(envelope('message_edited', payload: {'seq': 1})),
        isA<WsUnknown>(),
      );
      expect(
        parseWsEvent(envelope('message_deleted', payload: {'seq': 1})),
        isA<WsUnknown>(),
      );
    });
  });

  group('messages_read', () {
    test('parses the read watermark and its reader', () {
      final event = parseWsEvent(
        envelope(
          'messages_read',
          payload: {'chat_id': chatId, 'seq': 40, 'reader_id': 12},
        ),
      );

      expect(event, isA<MessagesRead>());
      final read = event as MessagesRead;
      expect(read.seq, 40);
      expect(read.readerId, 12);
    });

    test('degrades to Unknown without a reader_id', () {
      // Unattributable: it could be our own echo, which must be filtered out.
      final event = parseWsEvent(
        envelope('messages_read', payload: {'seq': 40}),
      );
      expect(event, isA<WsUnknown>());
    });
  });

  group('membership events', () {
    test('member_joined carries the chat role id', () {
      final event = parseWsEvent(
        envelope(
          'member_joined',
          payload: {'chat_id': chatId, 'user_id': 5, 'role_id': 3},
        ),
      );

      expect(event, isA<MemberJoined>());
      expect((event as MemberJoined).userId, 5);
      expect(event.roleId, 3);
    });

    test('member_left carries only the user', () {
      final event = parseWsEvent(
        envelope('member_left', payload: {'chat_id': chatId, 'user_id': 5}),
      );
      expect(event, isA<MemberLeft>());
      expect((event as MemberLeft).userId, 5);
    });

    test('member_kick distinguishes requester from target', () {
      final event = parseWsEvent(
        envelope(
          'member_kick',
          payload: {'chat_id': chatId, 'requester_id': 1, 'target_user_id': 5},
        ),
      );

      expect(event, isA<MemberKick>());
      final kick = event as MemberKick;
      expect(kick.requesterId, 1);
      expect(kick.targetUserId, 5);
    });

    test('member_banned with ban:true is a ban', () {
      final event = parseWsEvent(
        envelope(
          'member_banned',
          payload: {
            'chat_id': chatId,
            'requester_id': 1,
            'target_user_id': 5,
            'ban': true,
          },
        ),
      );
      expect((event as MemberBanned).ban, isTrue);
    });

    test('member_banned with ban:false is an UNban, not a ban', () {
      // The event name says "banned" but §7.4 uses it for both directions;
      // reading it as a ban unconditionally would drop every unban.
      final event = parseWsEvent(
        envelope(
          'member_banned',
          payload: {
            'chat_id': chatId,
            'requester_id': 1,
            'target_user_id': 5,
            'ban': false,
          },
        ),
      );
      expect(event, isA<MemberBanned>());
      expect((event as MemberBanned).ban, isFalse);
    });

    test('member_kick degrades to Unknown without a target', () {
      final event = parseWsEvent(
        envelope('member_kick', payload: {'requester_id': 1}),
      );
      expect(event, isA<WsUnknown>());
    });
  });

  group('chat lifecycle events', () {
    test('chat_created parses the member summary', () {
      final event = parseWsEvent(
        envelope(
          'chat_created',
          payload: {
            'chat_id': chatId,
            'created_by': 1,
            'name': 'Team',
            'member_ids': [1, 2, 3],
            'chat_type': 'supergroup',
            'member_count': 3,
          },
        ),
      );

      expect(event, isA<ChatCreated>());
      final created = event as ChatCreated;
      expect(created.createdBy, 1);
      expect(created.name, 'Team');
      expect(created.memberIds, [1, 2, 3]);
      // Never collapsed into "group" — §6.1 makes supergroup a distinct type.
      expect(created.chatType, 'supergroup');
      expect(created.memberCount, 3);
    });

    test('chat_created accepts a null name (direct chats have none)', () {
      final event = parseWsEvent(
        envelope(
          'chat_created',
          payload: {
            'chat_id': chatId,
            'created_by': 1,
            'name': null,
            'member_ids': [1, 2],
            'chat_type': 'direct',
            'member_count': 2,
          },
        ),
      );
      expect((event as ChatCreated).name, isNull);
      expect(event.chatType, 'direct');
    });

    test('chat_updated parses settings and the permission map', () {
      final event = parseWsEvent(
        envelope(
          'chat_updated',
          payload: {
            'chat_id': chatId,
            'updated_by': 1,
            'name': 'Renamed',
            'description': 'New topic',
            'is_public': true,
            'admin_only': false,
            'slow_mode_seconds': 30,
            'permissions': {'message:send': true, 'member:kick': false},
          },
        ),
      );

      expect(event, isA<ChatUpdated>());
      final updated = event as ChatUpdated;
      expect(updated.name, 'Renamed');
      expect(updated.description, 'New topic');
      expect(updated.isPublic, isTrue);
      expect(updated.adminOnly, isFalse);
      expect(updated.slowModeSeconds, 30);
      expect(updated.permissions, {'message:send': true, 'member:kick': false});
    });

    test('chat_updated drops non-bool permission values instead of coercing', () {
      // Guessing at `1` or `"true"` risks showing a button the server refuses.
      final event = parseWsEvent(
        envelope(
          'chat_updated',
          payload: {
            'chat_id': chatId,
            'updated_by': 1,
            'permissions': {'a': true, 'b': 'yes', 'c': 1},
          },
        ),
      );
      expect((event as ChatUpdated).permissions, {'a': true});
    });

    test('chat_deleted carries who deleted it', () {
      final event = parseWsEvent(
        envelope('chat_deleted', payload: {'chat_id': chatId, 'deleted_by': 1}),
      );
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
        'payload': {'message_id': 'm1', 'seq': 1},
        'ts': 'not-a-date',
      });

      expect(event, isA<NewMessage>());
      expect((event as NewMessage).ts, isNull);
    });
  });

  group('numeric coercion', () {
    test('accepts whole doubles for ints (JS-style JSON round-trips)', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          payload: {'message_id': 'm1', 'seq': 42.0, 'sender_id': 7.0},
        ),
      );

      expect(event, isA<NewMessage>());
      expect((event as NewMessage).seq, 42);
      expect(event.senderId, 7);
    });

    test('accepts numeric strings for ints', () {
      final event = parseWsEvent(
        envelope('new_message', payload: {'message_id': 'm1', 'seq': '42'}),
      );
      expect((event as NewMessage).seq, 42);
    });

    test('rejects a fractional seq as corruption', () {
      final event = parseWsEvent(
        envelope('new_message', payload: {'message_id': 'm1', 'seq': 4.5}),
      );
      expect(event, isA<WsUnknown>());
    });

    test('accepts 0/1 and "true"/"false" for booleans', () {
      final numeric = parseWsEvent(
        envelope(
          'member_banned',
          payload: {'chat_id': chatId, 'target_user_id': 5, 'ban': 0},
        ),
      );
      expect((numeric as MemberBanned).ban, isFalse);

      final textual = parseWsEvent(
        envelope(
          'member_banned',
          payload: {'chat_id': chatId, 'target_user_id': 5, 'ban': 'false'},
        ),
      );
      expect((textual as MemberBanned).ban, isFalse);
    });
  });

  group('parseWsFrame — transport level', () {
    test('decodes a JSON text frame, the form the socket delivers', () {
      final frame = jsonEncode({
        'type': 'new_message',
        'chat_id': chatId,
        'payload': {'message_id': 'm1', 'seq': 7, 'message_type': 'text'},
        'ts': '2026-01-15T10:30:00Z',
      });

      final event = parseWsFrame(frame);
      expect(event, isA<NewMessage>());
      expect((event as NewMessage).seq, 7);
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
        payload: {'message_id': 'm1', 'seq': 1, 'message_type': 'text'},
      );
      expect(parseWsEvent(raw), equals(parseWsEvent(Map.of(raw))));
    });

    test('a differing seq produces unequal events', () {
      final a = parseWsEvent(
        envelope('new_message', payload: {'message_id': 'm1', 'seq': 1}),
      );
      final b = parseWsEvent(
        envelope('new_message', payload: {'message_id': 'm1', 'seq': 2}),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
