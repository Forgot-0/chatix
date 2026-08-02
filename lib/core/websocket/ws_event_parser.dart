library;

import 'dart:convert';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/ws_event.dart';

/// Decodes server→client WebSocket frames into [WSEvent]s (api-docs §7.4).
///
/// A standalone, dependency-free, **pure** function — not a method on
/// `ChatSocketService` — for one reason: this is where every protocol
/// misunderstanding shows up, and it is the only part of the socket layer that
/// can be exhaustively tested without a server, a timer or a real connection.
/// `chat_socket_event_parser_test.dart` covers all 20 frame shapes by calling
/// [parseWsEvent] directly.
///
/// ## Never throws
///
/// Every entry point returns a [WSEvent]. Malformed JSON, a missing `type`, a
/// number where a string was promised, an absent `payload` — all degrade to
/// [WsUnknown] and a log line. This is a hard requirement, not defensiveness:
/// the parser runs inside the socket's `listen` callback, and an exception
/// escaping there kills the subscription and silently ends all live updates for
/// the rest of the session. A dropped frame costs one stale row; a thrown
/// exception costs the entire realtime layer.
///
/// ## Reading order
///
/// Frames are dispatched on `type`, with service (`ws.*`) frames handled
/// separately from domain events because — as §7.4 warns — they do **not**
/// share the envelope. Notably `ws.ping` and `ws.error` have no `payload`
/// wrapper at all.

/// Wire `type` → [WSEvent]. See library doc: never throws.
///
/// [raw] is the decoded JSON object of a single text frame.
WSEvent parseWsEvent(Map<String, dynamic> raw) {
  final type = raw['type'];
  if (type is! String || type.isEmpty) {
    // A frame with no usable discriminator. Nothing can be done with it, but
    // it is logged with its keys so an unexpected envelope change is visible.
    Logger.warning('WS frame without a "type" field: ${raw.keys.toList()}');
    return WsUnknown(type: '<missing>', raw: raw);
  }

  try {
    return switch (type) {
      // ── Service frames (§7.4). Handled first: they are the highest-volume
      // (`ws.ping` every 30 s) and the ones with irregular shapes.
      'ws.ready' => _parseReady(raw),
      'ws.subscribed' => _parseSubscribed(raw),
      'ws.unsubscribed' => _parseUnsubscribed(raw),
      'ws.history' => _parseHistory(raw),
      'ws.pong' => const WsPong(),
      'ws.ping' => _parsePing(raw),
      'ws.error' => _parseError(raw),

      // ── Domain events (§7.4).
      'new_message' => _parseNewMessage(raw),
      'message_edited' => _parseMessageEdited(raw),
      'message_deleted' => _parseMessageDeleted(raw),
      'messages_read' => _parseMessagesRead(raw),
      'member_joined' => _parseMemberJoined(raw),
      'member_left' => _parseMemberLeft(raw),
      'member_kick' => _parseMemberKick(raw),
      'member_banned' => _parseMemberBanned(raw),
      'chat_created' => _parseChatCreated(raw),
      'chat_updated' => _parseChatUpdated(raw),
      'attachment_success' => _parseAttachmentSuccess(raw),
      'chat_deleted' => _parseChatDeleted(raw),

      // ── Declared in the backend enum but never published (§7.4). Recognised
      // so they don't pollute the unknown-type logs, but intentionally inert.
      _ when WsUnimplementedEvent.types.contains(type) => WsUnimplementedEvent(
        type,
        chatId: _asString(raw['chat_id']),
        payload: _payloadOf(raw),
      ),

      // ── Anything else: a newer backend, or drift. Not an error.
      _ => _unknown(type, raw, 'unrecognised type'),
    };
  } catch (error, stackTrace) {
    // Belt and braces. The individual parsers are written to tolerate missing
    // and mistyped fields, so reaching here means a shape nobody anticipated —
    // still not worth killing the stream over.
    Logger.error('WS frame "$type" could not be parsed', error, stackTrace);
    return WsUnknown(type: type, raw: raw);
  }
}

/// Decodes a raw socket frame — the form `WebSocketChannel` actually delivers.
///
/// Accepts the `dynamic` that comes off the stream because a WS frame can be a
/// [String] (all of this protocol) or binary [List<int>] (none of it, but the
/// transport allows it, so it must not crash).
WSEvent parseWsFrame(dynamic frame) {
  final String text;
  switch (frame) {
    case String s:
      text = s;
    case List<int> bytes:
      // Not part of §7 — the server only sends text. Decoded rather than
      // rejected so a proxy that reframes text as binary doesn't break us.
      try {
        text = utf8.decode(bytes);
      } catch (error) {
        Logger.warning('WS binary frame is not valid UTF-8: $error');
        return WsUnknown(type: '<binary>', raw: {'bytes': bytes.length});
      }
    default:
      Logger.warning('WS frame of unexpected runtime type: ${frame.runtimeType}');
      return WsUnknown(type: '<invalid>', raw: {'runtimeType': '${frame.runtimeType}'});
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (error) {
    // Truncated to keep a flood of garbage from filling the log buffer.
    final preview = text.length > 200 ? '${text.substring(0, 200)}…' : text;
    Logger.warning('WS frame is not valid JSON: $preview');
    return WsUnknown(type: '<malformed>', raw: {'body': preview});
  }

  if (decoded is! Map<String, dynamic>) {
    Logger.warning('WS frame is not a JSON object: ${decoded.runtimeType}');
    return WsUnknown(type: '<malformed>', raw: {'decoded': '$decoded'});
  }

  return parseWsEvent(decoded);
}

// ───────────────────────────── Service frames ─────────────────────────────

WSEvent _parseReady(Map<String, dynamic> raw) {
  final payload = _payloadOf(raw);
  final reconnect = payload['reconnect'];
  final reconnectMap = reconnect is Map ? reconnect.cast<String, dynamic>() : const <String, dynamic>{};

  return WsReady(
    connectionId: _asString(payload['connection_id']) ?? '',
    gatewayId: _asString(payload['gateway_id']) ?? '',
    // Defaults mirror the documented server defaults (§7.2) so a stripped-down
    // `ws.ready` still yields a working heartbeat rather than a 0 s timer that
    // would spin the CPU sending pings.
    heartbeatInterval: _asInt(payload['heartbeat_interval']) ?? 30,
    heartbeatTimeout: _asInt(payload['heartbeat_timeout']) ?? 75,
    reconnectMode: _asString(reconnectMap['mode']),
    reconnectOp: _asString(reconnectMap['op']),
  );
}

WSEvent _parseSubscribed(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('ws.subscribed', raw, 'no chat_id');

  return WsSubscribed(
    chatId: chatId,
    // Genuinely nullable: an empty chat has no last seq (§7.4).
    lastSeq: _asInt(_payloadOf(raw)['last_seq']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseUnsubscribed(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('ws.unsubscribed', raw, 'no chat_id');
  return WsUnsubscribed(chatId: chatId, ts: _asDate(raw['ts']));
}

WSEvent _parseHistory(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('ws.history', raw, 'no chat_id');

  final payload = _payloadOf(raw);
  final rawMessages = payload['messages'];

  // Kept as maps, not decoded into models — see WsHistory's class doc. Non-map
  // entries are skipped individually so one bad row doesn't lose the batch.
  final messages = <Map<String, dynamic>>[];
  if (rawMessages is List) {
    for (final entry in rawMessages) {
      if (entry is Map) {
        messages.add(entry.cast<String, dynamic>());
      } else {
        Logger.warning('ws.history contained a non-object message entry, skipped');
      }
    }
  }

  return WsHistory(
    chatId: chatId,
    afterSeq: _asInt(payload['after_seq']) ?? 0,
    messages: messages,
    hasMore: _asBool(payload['has_more']) ?? false,
    nextLastSeq: _asInt(payload['next_last_seq']),
    ts: _asDate(raw['ts']),
  );
}

/// ⚠️ Reads `connection_id` from the **top level**: `ws.ping` has no `payload`
/// wrapper (§7.4).
WSEvent _parsePing(Map<String, dynamic> raw) {
  return WsPing(
    connectionId: _asString(raw['connection_id']),
    ts: _asDate(raw['ts']),
  );
}

/// Splits `ws.error` into its two very different meanings.
///
/// ⚠️ Also no `payload` wrapper — `code` and `detail` are top-level (§7.4).
WSEvent _parseError(Map<String, dynamic> raw) {
  final code = _asString(raw['code']);
  final detail = _asString(raw['detail']);
  final ts = _asDate(raw['ts']);

  // NOT_CHAT_MEMBER is server state we must react to (stop retrying that
  // chat); BAD_COMMAND/BAD_FRAME are client bugs. Different types, so a
  // consumer cannot accidentally treat one as the other.
  if (code == 'NOT_CHAT_MEMBER') {
    return WsErrorNotChatMember(code: code!, ts: ts, detail: detail);
  }

  if (code == 'BAD_COMMAND' || code == 'BAD_FRAME') {
    return WsErrorBadCommand(code: code!, detail: detail ?? '', ts: ts);
  }

  // An error code outside the documented three. Surfaced as bad-command rather
  // than unknown so it still reaches error logging, but only when there is a
  // code at all — a codeless `ws.error` tells us nothing.
  if (code != null) {
    Logger.warning('ws.error with undocumented code "$code": $detail');
    return WsErrorBadCommand(code: code, detail: detail ?? '', ts: ts);
  }

  return _unknown('ws.error', raw, 'no code');
}

// ───────────────────────────── Domain events ─────────────────────────────

WSEvent _parseNewMessage(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('new_message', raw, 'no chat_id');

  final payload = _payloadOf(raw);
  final messageId = _asString(payload['message_id']);
  final seq = _seqOf(raw, payload);

  // Both are load-bearing: without `message_id` the message cannot be
  // fetched, and without `seq` it cannot be ordered or used as a cursor. A
  // frame missing either is unusable, so it is surfaced rather than faked
  // with a 0 seq that would corrupt the resume cursor.
  if (messageId == null || seq == null) {
    return _unknown('new_message', raw, 'missing message_id/seq');
  }

  return NewMessage(
    chatId: chatId,
    messageId: messageId,
    seq: seq,
    // Legitimately null for `system` messages.
    senderId: _asInt(payload['sender_id']),
    messageType: _asString(payload['message_type']) ?? 'text',
    eventName: _asString(raw['event_name']),
    eventId: _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseMessageEdited(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('message_edited', raw, 'no chat_id');

  final payload = _payloadOf(raw);
  final messageId = _asString(payload['message_id']);
  final seq = _seqOf(raw, payload);
  if (messageId == null || seq == null) {
    return _unknown('message_edited', raw, 'missing message_id/seq');
  }

  return MessageEdited(
    chatId: chatId,
    messageId: messageId,
    seq: seq,
    modifiedBy: _asInt(payload['modified_by']) ?? 0,
    eventName: _asString(raw['event_name']),
    eventId: _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseMessageDeleted(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('message_deleted', raw, 'no chat_id');

  final payload = _payloadOf(raw);
  final messageId = _asString(payload['message_id']);
  final seq = _seqOf(raw, payload);
  if (messageId == null || seq == null) {
    return _unknown('message_deleted', raw, 'missing message_id/seq');
  }

  return MessageDeleted(
    chatId: chatId,
    messageId: messageId,
    seq: seq,
    deletedBy: _asInt(payload['deleted_by']) ?? 0,
    eventName: _asString(raw['event_name']),
    eventId: _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseMessagesRead(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('messages_read', raw, 'no chat_id');

  final payload = _payloadOf(raw);
  final seq = _seqOf(raw, payload);
  final readerId = _asInt(payload['reader_id']);

  // A read receipt with no seq marks nothing, and with no reader cannot be
  // attributed (or filtered out when it's our own echo).
  if (seq == null || readerId == null) {
    return _unknown('messages_read', raw, 'missing seq/reader_id');
  }

  return MessagesRead(
    chatId: chatId,
    seq: seq,
    readerId: readerId,
    eventName: _asString(raw['event_name']),
    eventId: _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseMemberJoined(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('member_joined', raw, 'no chat_id');

  final payload = _payloadOf(raw);
  final userId = _asInt(payload['user_id']);
  if (userId == null) return _unknown('member_joined', raw, 'missing user_id');

  return MemberJoined(
    chatId: chatId,
    userId: userId,
    roleId: _asInt(payload['role_id']) ?? 0,
    eventName: _asString(raw['event_name']),
    eventId: _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseMemberLeft(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('member_left', raw, 'no chat_id');

  final userId = _asInt(_payloadOf(raw)['user_id']);
  if (userId == null) return _unknown('member_left', raw, 'missing user_id');

  return MemberLeft(
    chatId: chatId,
    userId: userId,
    eventName: _asString(raw['event_name']),
    eventId: _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseMemberKick(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('member_kick', raw, 'no chat_id');

  final payload = _payloadOf(raw);
  final targetUserId = _asInt(payload['target_user_id']);
  // The *target* is what the UI acts on (remove that row; leave the chat if
  // it's us). Without it the event is inert.
  if (targetUserId == null) {
    return _unknown('member_kick', raw, 'missing target_user_id');
  }

  return MemberKick(
    chatId: chatId,
    requesterId: _asInt(payload['requester_id']) ?? 0,
    targetUserId: targetUserId,
    eventName: _asString(raw['event_name']),
    eventId: _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseMemberBanned(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('member_banned', raw, 'no chat_id');

  final payload = _payloadOf(raw);
  final targetUserId = _asInt(payload['target_user_id']);
  if (targetUserId == null) {
    return _unknown('member_banned', raw, 'missing target_user_id');
  }

  return MemberBanned(
    chatId: chatId,
    requesterId: _asInt(payload['requester_id']) ?? 0,
    targetUserId: targetUserId,
    // Defaults to `true` (banned) when absent: this event fires far more often
    // for bans than unbans, and under-reacting to a ban (leaving someone
    // visible who can no longer post) is the less confusing failure.
    ban: _asBool(payload['ban']) ?? true,
    eventName: _asString(raw['event_name']),
    eventId: _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseChatCreated(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('chat_created', raw, 'no chat_id');

  final payload = _payloadOf(raw);
  return ChatCreated(
    chatId: chatId,
    createdBy: _asInt(payload['created_by']) ?? 0,
    // Null is correct for direct chats, which have no stored name.
    name: _asString(payload['name']),
    memberIds: _asIntList(payload['member_ids']),
    chatType: _asString(payload['chat_type']) ?? 'direct',
    memberCount: _asInt(payload['member_count']) ?? 0,
    eventName: _asString(raw['event_name']),
    eventId: _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseChatUpdated(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('chat_updated', raw, 'no chat_id');

  final payload = _payloadOf(raw);
  final permissions = payload['permissions'];

  return ChatUpdated(
    chatId: chatId,
    updatedBy: _asInt(payload['updated_by']) ?? 0,
    name: _asString(payload['name']),
    description: _asString(payload['description']),
    isPublic: _asBool(payload['is_public']) ?? false,
    adminOnly: _asBool(payload['admin_only']) ?? false,
    slowModeSeconds: _asInt(payload['slow_mode_seconds']) ?? 0,
    permissions: permissions is Map
        ? {
            // Non-bool values are dropped rather than coerced: a permission
            // map is a security-adjacent input, and guessing at `"true"` vs
            // `1` is how a UI ends up showing a button the server will refuse.
            for (final entry in permissions.entries)
              if (entry.key is String && entry.value is bool)
                entry.key as String: entry.value as bool,
          }
        : const {},
    eventName: _asString(raw['event_name']),
    eventId: _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseAttachmentSuccess(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('attachment_success', raw, 'no chat_id');

  final payload = _payloadOf(raw);
  final tokens = payload['tokens'];

  return AttachmentSuccess(
    chatId: chatId,
    userId: _asInt(payload['user_id']) ?? 0,
    tokens: tokens is List
        ? [
            for (final token in tokens)
              if (_asString(token) case final String value) value,
          ]
        : const [],
    eventName: _asString(raw['event_name']),
    eventId: _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseChatDeleted(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown('chat_deleted', raw, 'no chat_id');

  return ChatDeleted(
    chatId: chatId,
    deletedBy: _asInt(_payloadOf(raw)['deleted_by']) ?? 0,
    eventName: _asString(raw['event_name']),
    eventId: _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

// ────────────────────────────── Field coercion ──────────────────────────────
//
// Every helper below returns null instead of throwing on a type mismatch. The
// callers above then decide, field by field, whether that field is essential
// (→ WsUnknown) or has a safe default. That split is the whole error strategy:
// only fields the UI cannot function without can lose a frame.

/// `payload`, or an empty map when absent/mistyped.
///
/// Absent is normal, not exceptional: `ws.ping` and `ws.error` have no payload
/// at all (§7.4), so this must not warn.
Map<String, dynamic> _payloadOf(Map<String, dynamic> raw) {
  final payload = raw['payload'];
  if (payload is Map) return payload.cast<String, dynamic>();
  return const {};
}

/// Resolves the chat id from the envelope, falling back to `payload.chat_id`.
///
/// §7.4 puts `chat_id` on the envelope but *also* repeats it inside the payload
/// of most domain events; the two are checked in that order so either shape
/// works. `null` means neither was present — an unroutable frame.
String? _chatIdOf(Map<String, dynamic> raw) {
  return _asString(raw['chat_id']) ?? _asString(_payloadOf(raw)['chat_id']);
}

/// `seq`, which §7.4 documents as duplicated at both levels.
///
/// Payload first: it is the value the emitting command actually set, whereas the
/// envelope copy is added by the delivery layer and is the one more likely to be
/// missing.
int? _seqOf(Map<String, dynamic> raw, Map<String, dynamic> payload) {
  return _asInt(payload['seq']) ?? _asInt(raw['seq']);
}

String? _asString(Object? value) => value is String ? value : null;

/// Tolerates the `int`/`double`/numeric-string forms JSON can produce.
///
/// Doubles arrive when a gateway round-trips numbers through a JS-style parser;
/// numeric strings when a serialiser stringifies large ids. Both mean the same
/// integer, and rejecting them would drop otherwise-valid events.
int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is double) {
    // Only whole doubles — 1.5 is not an id or a seq, it's corruption.
    return value == value.roundToDouble() ? value.toInt() : null;
  }
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _asBool(Object? value) {
  if (value is bool) return value;
  // Python's json emits real booleans, but 0/1 and "true"/"false" show up from
  // proxies and hand-written test fixtures.
  if (value is num) return value != 0;
  if (value is String) {
    final normalised = value.toLowerCase();
    if (normalised == 'true') return true;
    if (normalised == 'false') return false;
  }
  return null;
}

/// ISO 8601 (§1.9). Returns null rather than throwing on a bad string — `ts` is
/// metadata, never worth losing an event over.
DateTime? _asDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

/// `member_ids` and friends. Entries that aren't ints are skipped individually.
List<int> _asIntList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final entry in value)
      if (_asInt(entry) case final int id) id,
  ];
}

/// Logs why a frame was rejected and wraps it for the caller.
///
/// The reason string is what makes an unknown-frame log actionable — "no
/// chat_id" and "unrecognised type" call for completely different fixes.
WsUnknown _unknown(String type, Map<String, dynamic> raw, String reason) {
  Logger.warning('WS frame "$type" ignored ($reason): $raw');
  return WsUnknown(type: type, raw: raw);
}
