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

      // ── Domain events (§7.4). Each carries its own `payload.event` delta, so
      // each gets its own decoder rather than one generic one — the delta is
      // the whole point of the envelope, and a shared decoder could only hand
      // consumers an untyped map back.
      'new_message' => _parseNewMessage(raw),
      'message_edited' => _parseMessageEdited(raw),
      'message_deleted' => _parseMessageDeleted(raw),
      'messages_read' => _parseMessagesRead(raw),

      // Current short alias (§6.7.6) plus the raw domain-event name an older
      // backend build fanned out — see `ReactionUpdated.legacyWireType`.
      ReactionUpdated.wireType ||
      ReactionUpdated.legacyWireType => _parseReactionUpdated(raw),

      'member_joined' => _parseMemberJoined(raw),
      'member_left' => _parseMemberLeft(raw),
      'member_kick' => _parseMemberKick(raw),
      'member_banned' => _parseMemberBanned(raw),
      'chat_created' => _parseChatCreated(raw),
      'chat_updated' => _parseChatUpdated(raw),
      'chat_deleted' => _parseChatDeleted(raw),

      // ⚠️ The one domain event that does not use `MessagePayloadWS` — its
      // payload is a flat `AttachmentSuccessPayload` (§7.4).
      'attachment_success' => _parseAttachmentSuccess(raw),

      // ── Declared in the backend enum but never published (§7.4). Recognised
      // so they don't pollute the unknown-type logs, but intentionally inert.
      _ when WsUnimplementedEvent.types.contains(type) => WsUnimplementedEvent(
        type,
        chatId: _chatIdOf(raw),
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
//
// Every decoder below reads the same `MessagePayloadWS` envelope (§7.4):
//
//   { type, channel, payload: { event_id, event_name, event, message,
//                               reaction }, ts }
//
// `channel` carries the chat id; `payload.event` carries the delta. Each event
// type has its own decoder because each has its own delta — that is the point
// of the envelope. `attachment_success` is the sole exception and is decoded
// separately at the bottom.

/// Envelope fields shared by every domain event, pulled out once.
///
/// A record rather than a class: it exists for the length of one decode and
/// only spares the eleven decoders below from repeating four lookups each.
({String chatId, String? eventName, String? eventId, DateTime? ts})?
_envelopeOf(Map<String, dynamic> raw, String type) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) {
    _unknown(type, raw, 'no channel/chat_id');
    return null;
  }

  final payload = _payloadOf(raw);
  return (
    chatId: chatId,
    // ⚠️ Both live inside `payload`, not on the envelope (§7.4). The top-level
    // fallback is for older gateway builds that hoisted them, and costs
    // nothing.
    eventName: _asString(payload['event_name']) ?? _asString(raw['event_name']),
    eventId: _asString(payload['event_id']) ?? _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

/// `payload.event` — the per-type delta, or an empty map when absent/mistyped.
Map<String, dynamic> _deltaOf(Map<String, dynamic> raw) {
  final event = _payloadOf(raw)['event'];
  if (event is Map) return event.cast<String, dynamic>();
  return const {};
}

/// `payload.message` — the full `MessageDTO`, or `null`.
///
/// `null` is the **normal** case: only `new_message` and `message_edited`
/// carry one (§7.4). Kept as a raw map so `core/` need not import
/// `features/chat`'s `MessageModel` — see [NewMessage.message].
Map<String, dynamic>? _messageOf(Map<String, dynamic> raw) {
  final message = _payloadOf(raw)['message'];
  if (message is Map) return message.cast<String, dynamic>();
  return null;
}

WSEvent _parseNewMessage(Map<String, dynamic> raw) {
  final envelope = _envelopeOf(raw, 'new_message');
  if (envelope == null) return WsUnknown(type: 'new_message', raw: raw);

  final delta = _deltaOf(raw);
  final messageId = _asString(delta['message_id']);
  if (messageId == null) return _unknown('new_message', raw, 'no message_id');

  // The full DTO is the *point* of this event (§7.4) — a `new_message` without
  // one cannot be rendered, and fabricating an empty map would only crash the
  // first `MessageModel.fromJson` downstream.
  final message = _messageOf(raw);
  if (message == null) return _unknown('new_message', raw, 'no message');

  return NewMessage(
    chatId: envelope.chatId,
    messageId: messageId,
    seq: _asInt(delta['seq']),
    senderId: _asInt(delta['sender_id']),
    messageType: _asString(delta['message_type']),
    message: message,
    eventName: envelope.eventName,
    eventId: envelope.eventId,
    ts: envelope.ts,
  );
}

WSEvent _parseMessageEdited(Map<String, dynamic> raw) {
  final envelope = _envelopeOf(raw, 'message_edited');
  if (envelope == null) return WsUnknown(type: 'message_edited', raw: raw);

  final delta = _deltaOf(raw);
  final messageId = _asString(delta['message_id']);
  if (messageId == null) {
    return _unknown('message_edited', raw, 'no message_id');
  }

  // Same reasoning as `new_message`: the post-edit DTO is what makes this
  // event actionable without a refetch.
  final message = _messageOf(raw);
  if (message == null) return _unknown('message_edited', raw, 'no message');

  return MessageEdited(
    chatId: envelope.chatId,
    messageId: messageId,
    seq: _asInt(delta['seq']),
    modifiedBy: _asInt(delta['modified_by']),
    message: message,
    eventName: envelope.eventName,
    eventId: envelope.eventId,
    ts: envelope.ts,
  );
}

WSEvent _parseMessageDeleted(Map<String, dynamic> raw) {
  final envelope = _envelopeOf(raw, 'message_deleted');
  if (envelope == null) return WsUnknown(type: 'message_deleted', raw: raw);

  final delta = _deltaOf(raw);
  final messageId = _asString(delta['message_id']);
  if (messageId == null) {
    return _unknown('message_deleted', raw, 'no message_id');
  }

  // ⚠️ No `message` expected here — §7.4 sends `null`, since the row is gone.
  return MessageDeleted(
    chatId: envelope.chatId,
    messageId: messageId,
    seq: _asInt(delta['seq']),
    deletedBy: _asInt(delta['deleted_by']),
    eventName: envelope.eventName,
    eventId: envelope.eventId,
    ts: envelope.ts,
  );
}

WSEvent _parseMessagesRead(Map<String, dynamic> raw) {
  final envelope = _envelopeOf(raw, 'messages_read');
  if (envelope == null) return WsUnknown(type: 'messages_read', raw: raw);

  final delta = _deltaOf(raw);
  final seq = _asInt(delta['seq']);
  final readerId = _asInt(delta['reader_id']);

  // Both are load-bearing: without `seq` there is no position to move to, and
  // without `reader_id` the receipt cannot be attributed — and misattributing
  // a peer's read as our own would wrongly clear the unread badge.
  if (seq == null || readerId == null) {
    return _unknown('messages_read', raw, 'missing seq/reader_id');
  }

  return MessagesRead(
    chatId: envelope.chatId,
    seq: seq,
    readerId: readerId,
    eventName: envelope.eventName,
    eventId: envelope.eventId,
    ts: envelope.ts,
  );
}

WSEvent _parseReactionUpdated(Map<String, dynamic> raw) {
  final envelope = _envelopeOf(raw, ReactionUpdated.wireType);
  if (envelope == null) {
    return WsUnknown(type: ReactionUpdated.wireType, raw: raw);
  }

  final delta = _deltaOf(raw);
  final payload = _payloadOf(raw);

  // ⚠️ The snapshot lives in `payload.reaction`, *beside* the delta — not in
  // `payload.message`, which is null for this event (§6.7.6).
  final reaction = payload['reaction'];
  if (reaction is! Map) {
    return _unknown(ReactionUpdated.wireType, raw, 'no reaction snapshot');
  }
  final reactionMap = reaction.cast<String, dynamic>();

  // `event.message_id` is the documented home; the snapshot repeats it, which
  // is the fallback for a build that only fills one of the two.
  final messageId =
      _asString(delta['message_id']) ?? _asString(reactionMap['message_id']);
  if (messageId == null) {
    return _unknown(ReactionUpdated.wireType, raw, 'no message_id');
  }

  return ReactionUpdated(
    chatId: envelope.chatId,
    messageId: messageId,
    actorId: _asInt(delta['actor_id']) ?? _asInt(reactionMap['actor_id']),
    action: _asString(delta['action']) ?? _asString(reactionMap['action']),
    reaction: reactionMap,
    eventName: envelope.eventName,
    eventId: envelope.eventId,
    ts: envelope.ts,
  );
}

WSEvent _parseMemberJoined(Map<String, dynamic> raw) {
  final envelope = _envelopeOf(raw, 'member_joined');
  if (envelope == null) return WsUnknown(type: 'member_joined', raw: raw);

  final delta = _deltaOf(raw);
  final userId = _asInt(delta['user_id']);
  if (userId == null) return _unknown('member_joined', raw, 'no user_id');

  return MemberJoined(
    chatId: envelope.chatId,
    userId: userId,
    roleId: _asInt(delta['role_id']),
    eventName: envelope.eventName,
    eventId: envelope.eventId,
    ts: envelope.ts,
  );
}

WSEvent _parseMemberLeft(Map<String, dynamic> raw) {
  final envelope = _envelopeOf(raw, 'member_left');
  if (envelope == null) return WsUnknown(type: 'member_left', raw: raw);

  final userId = _asInt(_deltaOf(raw)['user_id']);
  // Essential: "who left" is the only thing separating "drop this chat" from
  // "decrement a counter" (see `MemberLeft`'s class doc).
  if (userId == null) return _unknown('member_left', raw, 'no user_id');

  return MemberLeft(
    chatId: envelope.chatId,
    userId: userId,
    eventName: envelope.eventName,
    eventId: envelope.eventId,
    ts: envelope.ts,
  );
}

WSEvent _parseMemberKick(Map<String, dynamic> raw) {
  final envelope = _envelopeOf(raw, 'member_kick');
  if (envelope == null) return WsUnknown(type: 'member_kick', raw: raw);

  final delta = _deltaOf(raw);
  final targetUserId = _asInt(delta['target_user_id']);
  if (targetUserId == null) {
    return _unknown('member_kick', raw, 'no target_user_id');
  }

  return MemberKick(
    chatId: envelope.chatId,
    targetUserId: targetUserId,
    requesterId: _asInt(delta['requester_id']),
    eventName: envelope.eventName,
    eventId: envelope.eventId,
    ts: envelope.ts,
  );
}

WSEvent _parseMemberBanned(Map<String, dynamic> raw) {
  final envelope = _envelopeOf(raw, 'member_banned');
  if (envelope == null) return WsUnknown(type: 'member_banned', raw: raw);

  final delta = _deltaOf(raw);
  final targetUserId = _asInt(delta['target_user_id']);
  if (targetUserId == null) {
    return _unknown('member_banned', raw, 'no target_user_id');
  }

  return MemberBanned(
    chatId: envelope.chatId,
    targetUserId: targetUserId,
    // ⚠️ Defaults to `true`, not `false`: this event covers both directions
    // (§7.4), and treating a malformed frame as an *unban* would silently
    // restore access the server has revoked. Erring towards "banned" is the
    // safe direction — the next chat fetch corrects it either way.
    ban: _asBool(delta['ban']) ?? true,
    requesterId: _asInt(delta['requester_id']),
    eventName: envelope.eventName,
    eventId: envelope.eventId,
    ts: envelope.ts,
  );
}

WSEvent _parseChatCreated(Map<String, dynamic> raw) {
  final envelope = _envelopeOf(raw, 'chat_created');
  if (envelope == null) return WsUnknown(type: 'chat_created', raw: raw);

  final delta = _deltaOf(raw);
  final memberIds = delta['member_ids'];

  return ChatCreated(
    chatId: envelope.chatId,
    createdBy: _asInt(delta['created_by']),
    name: _asString(delta['name']),
    chatType: _asString(delta['chat_type']),
    memberIds: memberIds is List
        ? [
            for (final id in memberIds)
              if (_asInt(id) case final int value) value,
          ]
        : const [],
    memberCount: _asInt(delta['member_count']),
    eventName: envelope.eventName,
    eventId: envelope.eventId,
    ts: envelope.ts,
  );
}

WSEvent _parseChatUpdated(Map<String, dynamic> raw) {
  final envelope = _envelopeOf(raw, 'chat_updated');
  if (envelope == null) return WsUnknown(type: 'chat_updated', raw: raw);

  final delta = _deltaOf(raw);
  final permissions = delta['permissions'];
  final allowed = delta['allowed_reactions'];

  // ⚠️ Every field stays nullable and no default is invented. A `null` here
  // means "not part of this change" (§6.2 — PATCH cannot null a field out), so
  // substituting `false`/`0`/`{}` would turn "untouched" into a real edit and
  // silently reset the chat's settings locally.
  return ChatUpdated(
    chatId: envelope.chatId,
    updatedBy: _asInt(delta['updated_by']),
    name: _asString(delta['name']),
    description: _asString(delta['description']),
    isPublic: _asBool(delta['is_public']),
    adminOnly: _asBool(delta['admin_only']),
    slowModeSeconds: _asInt(delta['slow_mode_seconds']),
    permissions: permissions is Map
        ? {
            for (final entry in permissions.entries)
              if (_asBool(entry.value) case final bool value)
                '${entry.key}': value,
          }
        : null,
    reactionsMode: _asString(delta['reactions_mode']),
    allowedReactions: allowed is List
        ? [
            for (final emoji in allowed)
              if (_asString(emoji) case final String value) value,
          ]
        : null,
    eventName: envelope.eventName,
    eventId: envelope.eventId,
    ts: envelope.ts,
  );
}

WSEvent _parseChatDeleted(Map<String, dynamic> raw) {
  final envelope = _envelopeOf(raw, 'chat_deleted');
  if (envelope == null) return WsUnknown(type: 'chat_deleted', raw: raw);

  return ChatDeleted(
    chatId: envelope.chatId,
    deletedBy: _asInt(_deltaOf(raw)['deleted_by']),
    eventName: envelope.eventName,
    eventId: envelope.eventId,
    ts: envelope.ts,
  );
}

/// ⚠️ The one domain event with a different payload shape (§7.4): a flat
/// `AttachmentSuccessPayload { user_id, chat_id, tokens }` with no `event`
/// block — so the fields are read from `payload` directly, and `chat_id` lives
/// there rather than only in `channel`.
WSEvent _parseAttachmentSuccess(Map<String, dynamic> raw) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) {
    return _unknown('attachment_success', raw, 'no channel/chat_id');
  }

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
    eventName: _asString(payload['event_name']) ?? _asString(raw['event_name']),
    eventId: _asString(payload['event_id']) ?? _asString(raw['event_id']),
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

/// Resolves the chat id a frame is about.
///
/// Three sources, in order, because the protocol genuinely uses three:
///
/// * **`channel`** — where domain events carry it (§7.4). The delta never
///   repeats it, so for those this is the only source.
/// * **`chat_id`** — where the service frames (`ws.subscribed`,
///   `ws.unsubscribed`, `ws.history`) carry it.
/// * **`payload.chat_id`** — `attachment_success`, whose payload is a flat
///   `AttachmentSuccessPayload` that includes it.
///
/// `null` means none was present — an unroutable frame.
String? _chatIdOf(Map<String, dynamic> raw) {
  return _asString(raw['channel']) ??
      _asString(raw['chat_id']) ??
      _asString(_payloadOf(raw)['chat_id']);
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

/// Logs why a frame was rejected and wraps it for the caller.
///
/// The reason string is what makes an unknown-frame log actionable — "no
/// chat_id" and "unrecognised type" call for completely different fixes.
WsUnknown _unknown(String type, Map<String, dynamic> raw, String reason) {
  Logger.warning('WS frame "$type" ignored ($reason): $raw');
  return WsUnknown(type: type, raw: raw);
}
