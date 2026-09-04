import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/core/websocket/ws_event_parser.dart';

/// Unit tests for the §7.4 frame decoder.
///
/// **No socket, no server, no timers** — [parseWsEvent]/[parseWsFrame] are pure
/// functions, which is the reason they were factored out of
/// `ChatSocketService`. Everything the protocol can get wrong (a domain event
/// whose delta is missing its identifying field, the `payload`-less `ws.ping`,
/// the two meanings of `ws.error`) is decidable from a JSON literal.
///
/// Fixtures are written as the docs write them — snake_case, full envelope,
/// `channel` for domain events and `chat_id` for service frames — so a
/// mismatch between this file and api-docs §7.4 is visible by eye.
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';

  /// The §7.4 domain envelope: `{ type, channel, payload, ts }`, where
  /// `payload` is a `MessagePayloadWS`.
  ///
  /// ⚠️ `event_id`/`event_name` go **inside** `payload`, not on the envelope —
  /// getting that wrong is exactly the bug this shape is written to catch,
  /// since `event_id` is the at-least-once dedup key.
  Map<String, dynamic> envelope(
    String type, {
    String? channel = chatId,
    Map<String, dynamic> event = const {},
    Map<String, dynamic>? message,
    Map<String, dynamic>? reaction,
    String? eventName,
    String? eventId,
    String ts = '2026-01-15T10:30:00Z',
  }) {
    return {
      'type': type,
      'channel': ?channel,
      'payload': {
        'event_id': ?eventId,
        'event_name': ?eventName,
        'event': event,
        'message': message,
        'reaction': ?reaction,
      },
      'ts': ts,
    };
  }

  /// A minimal `MessageDTO`. The parser only checks it is a *map* — decoding
  /// its fields into a `MessageModel` is the feature layer's job, tested
  /// separately — so the fixture stays minimal rather than a full DTO.
  const messageDto = {'id': 'm1', 'chat_id': chatId, 'seq': 1};

  group('envelope (§7.4)', () {
    test('chat id comes from `channel`, not a repeated payload field', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          event: const {'message_id': 'm1', 'seq': 1},
          message: messageDto,
        ),
      );

      expect(event, isA<NewMessage>());
      expect((event as NewMessage).chatId, chatId);
    });

    test('event_id and event_name are read from inside the payload', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          eventId: 'evt-1',
          eventName: 'chats.message.sent',
          event: const {'message_id': 'm1', 'seq': 1},
          message: messageDto,
        ),
      );

      final domain = event as WSDomainEvent;
      // event_id is the dedup key for at-least-once delivery — reading it from
      // the wrong level would silently disable deduplication.
      expect(domain.eventId, 'evt-1');
      expect(domain.eventName, 'chats.message.sent');
      expect(domain.ts, DateTime.parse('2026-01-15T10:30:00Z'));
    });

    test('a domain frame with no channel degrades to Unknown', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          channel: null,
          event: const {'message_id': 'm1'},
          message: messageDto,
        ),
      );
      expect(event, isA<WsUnknown>());
    });
  });

  group('message events (§7.4)', () {
    test('new_message carries the delta AND the full MessageDTO', () {
      final event = parseWsEvent(
        envelope(
          'new_message',
          event: const {
            'message_id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
            'seq': 42,
            'sender_id': 7,
            'message_type': 'voice',
          },
          message: const {
            'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
            'chat_id': chatId,
            'seq': 42,
            'content': 'hello',
          },
        ),
      );

      expect(event, isA<NewMessage>());
      final newMessage = event as NewMessage;
      expect(newMessage.messageId, 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
      expect(newMessage.seq, 42);
      expect(newMessage.senderId, 7);
      // Available without decoding the DTO — what a cheap list preview needs.
      expect(newMessage.messageType, 'voice');
      // Kept raw: `core/` must not import the feature's MessageModel.
      expect(newMessage.message['content'], 'hello');
    });

    test('new_message without a MessageDTO degrades to Unknown', () {
      // The full DTO is the point of this event (§7.4) — a `new_message`
      // without one cannot be rendered, and fabricating an empty map would
      // only crash the first MessageModel.fromJson downstream.
      final event = parseWsEvent(
        envelope('new_message', event: const {'message_id': 'm1', 'seq': 1}),
      );
      expect(event, isA<WsUnknown>());
    });

    test('new_message without a message_id degrades to Unknown', () {
      final event = parseWsEvent(
        envelope('new_message', event: const {'seq': 1}, message: messageDto),
      );
      expect(event, isA<WsUnknown>());
    });

    test('message_edited carries modified_by and the post-edit DTO', () {
      final event = parseWsEvent(
        envelope(
          'message_edited',
          event: const {'message_id': 'm1', 'seq': 42, 'modified_by': 7},
          message: const {'id': 'm1', 'chat_id': chatId, 'content': 'fixed'},
        ),
      );

      expect(event, isA<MessageEdited>());
      final edited = event as MessageEdited;
      expect(edited.messageId, 'm1');
      expect(edited.seq, 42);
      expect(edited.modifiedBy, 7);
      expect(edited.message['content'], 'fixed');
    });

    test('message_deleted needs no MessageDTO — the delta is enough', () {
      // `payload.message` is null here by design (§7.4): the row is gone, and
      // re-fetching it would only 404.
      final event = parseWsEvent(
        envelope(
          'message_deleted',
          event: const {'message_id': 'm1', 'seq': 42, 'deleted_by': 9},
        ),
      );

      expect(event, isA<MessageDeleted>());
      final deleted = event as MessageDeleted;
      expect(deleted.messageId, 'm1');
      expect(deleted.seq, 42);
      // May be a moderator rather than the author (`message:delete`, §9.1).
      expect(deleted.deletedBy, 9);
    });

    test('the three message events share WSMessageEvent, for cursor work', () {
      // `ChatSocketService` advances the resume cursor by switching on this
      // one base type rather than three unrelated classes.
      for (final raw in [
        envelope(
          'new_message',
          event: const {'message_id': 'm1', 'seq': 5},
          message: messageDto,
        ),
        envelope(
          'message_edited',
          event: const {'message_id': 'm1', 'seq': 5},
          message: messageDto,
        ),
        envelope('message_deleted', event: const {'message_id': 'm1', 'seq': 5}),
      ]) {
        final event = parseWsEvent(raw);
        expect(event, isA<WSMessageEvent>());
        expect((event as WSMessageEvent).seq, 5);
      }
    });

    test('seq tolerates the whole-double and numeric-string JSON forms', () {
      final asDouble = parseWsEvent(
        envelope(
          'message_deleted',
          event: const {'message_id': 'm1', 'seq': 42.0},
        ),
      );
      expect((asDouble as MessageDeleted).seq, 42);

      final asString = parseWsEvent(
        envelope(
          'message_deleted',
          event: const {'message_id': 'm1', 'seq': '42'},
        ),
      );
      expect((asString as MessageDeleted).seq, 42);
    });

    test('a fractional seq is corruption, not an id — dropped to null', () {
      final event = parseWsEvent(
        envelope(
          'message_deleted',
          event: const {'message_id': 'm1', 'seq': 4.5},
        ),
      );
      expect((event as MessageDeleted).seq, isNull);
    });
  });

  group('messages_read (§7.4)', () {
    test('carries both the position and the reader', () {
      final event = parseWsEvent(
        envelope('messages_read', event: const {'seq': 42, 'reader_id': 7}),
      );

      expect(event, isA<MessagesRead>());
      final read = event as MessagesRead;
      expect(read.seq, 42);
      // The identity is what separates "I read this elsewhere" from "a peer
      // read it" — without it a receipt would clear the wrong badge.
      expect(read.readerId, 7);
    });

    test('a receipt missing reader_id degrades to Unknown', () {
      // Unattributable: applying it would either clear our own unread badge on
      // a peer's read, or show a double tick we never earned.
      final event = parseWsEvent(
        envelope('messages_read', event: const {'seq': 42}),
      );
      expect(event, isA<WsUnknown>());
    });

    test('a receipt missing seq degrades to Unknown', () {
      final event = parseWsEvent(
        envelope('messages_read', event: const {'reader_id': 7}),
      );
      expect(event, isA<WsUnknown>());
    });
  });

  group('reaction_update (§6.7.6)', () {
    Map<String, dynamic> reactionBlock({
      List<Map<String, dynamic>> groups = const [
        {
          'emoji': '👍',
          'count': 3,
          'version': 5,
          'reacted_by_me': false,
          'recent_user_ids': [7, 8],
        },
      ],
    }) => {
      'message_id': 'm1',
      'chat_id': chatId,
      'actor_id': 7,
      'action': 'add',
      'groups': groups,
    };

    test('reads the snapshot from payload.reaction, not payload.message', () {
      final event = parseWsEvent(
        envelope(
          'reaction_update',
          event: const {'message_id': 'm1', 'actor_id': 7, 'action': 'add'},
          reaction: reactionBlock(),
        ),
      );

      expect(event, isA<ReactionUpdated>());
      final updated = event as ReactionUpdated;
      expect(updated.messageId, 'm1');
      expect(updated.actorId, 7);
      expect(updated.action, 'add');
      // Raw map — decoded by the feature with ReactionUpdateModel.
      expect((updated.reaction['groups'] as List).length, 1);
    });

    test('without a reaction block it degrades to Unknown', () {
      // There is nothing else to apply: `payload.message` is null for this
      // event, so a frame with no snapshot conveys nothing.
      final event = parseWsEvent(
        envelope('reaction_update', event: const {'message_id': 'm1'}),
      );
      expect(event, isA<WsUnknown>());
    });

    test('message_id falls back to the snapshot when the delta omits it', () {
      final event = parseWsEvent(
        envelope('reaction_update', reaction: reactionBlock()),
      );
      expect(event, isA<ReactionUpdated>());
      expect((event as ReactionUpdated).messageId, 'm1');
    });

    test('the legacy raw domain-event name is still recognised', () {
      // An older backend build fanned this out before CHAT_EVENT_TO_WS_TYPE
      // gained an entry; recognising it costs nothing and beats WsUnknown.
      final event = parseWsEvent(
        envelope(
          ReactionUpdated.legacyWireType,
          event: const {'message_id': 'm1'},
          reaction: reactionBlock(),
        ),
      );

      expect(event, isA<ReactionUpdated>());
      // Normalised to the current wire type, so consumers only see one value.
      expect(event.type, ReactionUpdated.wireType);
    });
  });

  group('membership events (§7.4)', () {
    test('member_joined carries the user and their starting role', () {
      final event = parseWsEvent(
        envelope('member_joined', event: const {'user_id': 7, 'role_id': 5}),
      );

      expect(event, isA<MemberJoined>());
      expect((event as MemberJoined).userId, 7);
      expect(event.roleId, 5);
    });

    test('member_left names who left', () {
      // Also delivered directly to the leaver (§7.4), so the identity is what
      // decides "drop the chat" vs "decrement the count".
      final event = parseWsEvent(
        envelope('member_left', event: const {'user_id': 7}),
      );

      expect(event, isA<MemberLeft>());
      expect((event as MemberLeft).userId, 7);
    });

    test('member_left without a user_id degrades to Unknown', () {
      final event = parseWsEvent(envelope('member_left'));
      expect(event, isA<WsUnknown>());
    });

    test('member_kick names both the target and the requester', () {
      final event = parseWsEvent(
        envelope(
          'member_kick',
          event: const {'target_user_id': 7, 'requester_id': 1},
        ),
      );

      expect(event, isA<MemberKick>());
      final kick = event as MemberKick;
      expect(kick.targetUserId, 7);
      expect(kick.requesterId, 1);
    });

    test('member_banned distinguishes ban from unban', () {
      final banned = parseWsEvent(
        envelope(
          'member_banned',
          event: const {'target_user_id': 7, 'requester_id': 1, 'ban': true},
        ),
      );
      expect((banned as MemberBanned).ban, isTrue);
      expect(banned.targetUserId, 7);

      final unbanned = parseWsEvent(
        envelope(
          'member_banned',
          event: const {'target_user_id': 7, 'ban': false},
        ),
      );
      expect((unbanned as MemberBanned).ban, isFalse);
    });

    test('a member_banned with no ban flag defaults to banned', () {
      // Erring towards "banned" is the safe direction: treating a malformed
      // frame as an unban would restore access the server has revoked.
      final event = parseWsEvent(
        envelope('member_banned', event: const {'target_user_id': 7}),
      );
      expect((event as MemberBanned).ban, isTrue);
    });
  });

  group('chat lifecycle events (§7.4)', () {
    test('chat_created carries the summary needed for a provisional row', () {
      final event = parseWsEvent(
        envelope(
          'chat_created',
          event: const {
            'created_by': 1,
            'name': 'Team',
            'chat_type': 'group',
            'member_ids': [1, 2, 3],
            'member_count': 3,
          },
        ),
      );

      expect(event, isA<ChatCreated>());
      final created = event as ChatCreated;
      expect(created.createdBy, 1);
      expect(created.name, 'Team');
      expect(created.chatType, 'group');
      expect(created.memberIds, [1, 2, 3]);
      expect(created.memberCount, 3);
    });

    test('chat_updated carries the settings delta, reactions included', () {
      final event = parseWsEvent(
        envelope(
          'chat_updated',
          event: const {
            'updated_by': 1,
            'name': 'Renamed',
            'slow_mode_seconds': 30,
            'permissions': {'message:send': false},
            'reactions_mode': 'some',
            'allowed_reactions': ['👍', '🔥'],
          },
        ),
      );

      expect(event, isA<ChatUpdated>());
      final updated = event as ChatUpdated;
      expect(updated.updatedBy, 1);
      expect(updated.name, 'Renamed');
      expect(updated.slowModeSeconds, 30);
      expect(updated.permissions, {'message:send': false});
      expect(updated.reactionsMode, 'some');
      expect(updated.allowedReactions, ['👍', '🔥']);
    });

    test('chat_updated leaves absent fields null — "unchanged", not cleared', () {
      // PATCH /chats/{id}/ cannot null a field out (§6.2), so a missing key can
      // only mean "untouched". Inventing false/0/{} here would silently reset
      // the chat's settings locally.
      final event = parseWsEvent(
        envelope('chat_updated', event: const {'name': 'Renamed'}),
      );

      final updated = event as ChatUpdated;
      expect(updated.name, 'Renamed');
      expect(updated.description, isNull);
      expect(updated.isPublic, isNull);
      expect(updated.adminOnly, isNull);
      expect(updated.slowModeSeconds, isNull);
      expect(updated.permissions, isNull);
      expect(updated.reactionsMode, isNull);
      expect(updated.allowedReactions, isNull);
    });

    test('chat_deleted carries who deleted it', () {
      final event = parseWsEvent(
        envelope('chat_deleted', event: const {'deleted_by': 1}),
      );

      expect(event, isA<ChatDeleted>());
      expect((event as ChatDeleted).deletedBy, 1);
      expect(event.chatId, chatId);
    });
  });

  group('attachment_success', () {
    test('reads a FLAT payload — it has no event/message block', () {
      // ⚠️ The one domain event that does not use MessagePayloadWS (§7.4).
      final event = parseWsEvent({
        'type': 'attachment_success',
        'channel': chatId,
        'payload': {
          'user_id': 7,
          'chat_id': chatId,
          'tokens': ['t1', 't2'],
        },
        'ts': '2026-01-15T10:30:00Z',
      });

      expect(event, isA<AttachmentSuccess>());
      final success = event as AttachmentSuccess;
      expect(success.chatId, chatId);
      expect(success.userId, 7);
      expect(success.tokens, ['t1', 't2']);
    });

    test('resolves chat_id from inside the payload when channel is absent', () {
      final event = parseWsEvent({
        'type': 'attachment_success',
        'payload': {
          'user_id': 7,
          'chat_id': chatId,
          'tokens': ['t1'],
        },
      });

      expect(event, isA<AttachmentSuccess>());
      expect((event as AttachmentSuccess).chatId, chatId);
    });

    test('missing tokens yield an empty list, not a dropped frame', () {
      final event = parseWsEvent({
        'type': 'attachment_success',
        'channel': chatId,
        'payload': {'user_id': 7},
      });

      expect(event, isA<AttachmentSuccess>());
      expect((event as AttachmentSuccess).tokens, isEmpty);
    });

    test('non-string token entries are skipped, keeping the rest', () {
      final event = parseWsEvent({
        'type': 'attachment_success',
        'channel': chatId,
        'payload': {
          'user_id': 7,
          'tokens': ['t1', 42, null, 't2'],
        },
      });

      expect((event as AttachmentSuccess).tokens, ['t1', 't2']);
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
        final event = parseWsEvent(envelope(type, event: {'user_id': 1}));
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
        'channel': chatId,
        'payload': {
          'event': {'message_id': 'm1', 'seq': 1},
          'message': messageDto,
        },
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
        'channel': chatId,
        'payload': {
          'event_id': 'evt-1',
          'event': {'message_id': 'm1', 'seq': 7, 'sender_id': 3},
          'message': {'id': 'm1', 'chat_id': chatId, 'seq': 7},
        },
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
        eventId: 'evt-1',
        event: const {'message_id': 'm1', 'seq': 1},
        message: messageDto,
      );
      expect(parseWsEvent(raw), equals(parseWsEvent(Map.of(raw))));
    });

    test('a differing seq produces unequal events', () {
      final a = parseWsEvent(
        envelope(
          'new_message',
          event: const {'message_id': 'm1', 'seq': 1},
          message: messageDto,
        ),
      );
      final b = parseWsEvent(
        envelope(
          'new_message',
          event: const {'message_id': 'm1', 'seq': 2},
          message: messageDto,
        ),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
