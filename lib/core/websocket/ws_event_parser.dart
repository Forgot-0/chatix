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

      // ── Domain events (§7.4, revised). All of these now share the generic
      // `MessagePayloadWS { chat, message }` envelope, so one generic decoder
      // handles them all — see `_parseChatMessageEvent`.
      'new_message' => _parseChatMessageEvent(raw, 'new_message', NewMessage.new),
      'message_edited' => _parseChatMessageEvent(raw, 'message_edited', MessageEdited.new),
      'message_deleted' => _parseChatMessageEvent(raw, 'message_deleted', MessageDeleted.new),
      'messages_read' => _parseChatMessageEvent(raw, 'messages_read', MessagesRead.new),

      // Current short alias (api-docs §6.7.5, revised) plus the previous raw
      // domain-event name, in case an older backend build is still fanning
      // that one out — see `ReactionUpdated.legacyWireType`.
      ReactionUpdated.wireType ||
      ReactionUpdated.legacyWireType => _parseChatMessageEvent(
        raw,
        ReactionUpdated.wireType,
        ReactionUpdated.new,
      ),

      'member_joined' => _parseChatMessageEvent(raw, 'member_joined', MemberJoined.new),
      'member_left' => _parseChatMessageEvent(raw, 'member_left', MemberLeft.new),
      'member_kick' => _parseChatMessageEvent(raw, 'member_kick', MemberKick.new),
      'member_banned' => _parseChatMessageEvent(raw, 'member_banned', MemberBanned.new),
      'chat_created' => _parseChatMessageEvent(raw, 'chat_created', ChatCreated.new),
      'chat_updated' => _parseChatMessageEvent(raw, 'chat_updated', ChatUpdated.new),

      // Unaffected by the §7.4 payload revision — its own `AttachmentSuccessPayload`
      // shape (`user_id`/`chat_id`/`tokens`) is untouched.
      'attachment_success' => _parseAttachmentSuccess(raw),

      // Not currently defined in the backend's `WSEventType` enum at all
      // (api-docs §7.4, revised) — see `ChatDeleted`'s class doc. Parsed
      // defensively in case a future build adds it.
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

/// Constructor shape shared by every [WSChatMessageEvent] subclass — a
/// constructor tear-off like `NewMessage.new` matches this directly, so
/// `_parseChatMessageEvent` can be handed the right one per wire type instead
/// of duplicating the same decode logic eleven times.
typedef _ChatMessageEventFactory =
    WSChatMessageEvent Function({
      required String chatId,
      required Map<String, dynamic> chat,
      required Map<String, dynamic> message,
      String? eventName,
      String? eventId,
      DateTime? ts,
    });

/// Decodes the generic `MessagePayloadWS { chat, message }` envelope shared by
/// `new_message`, `message_edited`, `message_deleted`, `messages_read`,
/// `member_joined`, `member_left`, `member_kick`, `member_banned`,
/// `chat_created`, `chat_updated` and `reaction_update` (api-docs §7.4,
/// revised — see [WSChatMessageEvent]'s class doc for why these eleven
/// converged on one shape).
///
/// Both `chat` and `message` are required. Older, event-specific payloads
/// could get away with fewer required fields (`messages_read` needed no
/// `message` at all, conceptually) but the current backend implementation
/// fetches both unconditionally for anything routed through
/// `ChatDeliveryRouter`, so a frame missing either is not a smaller version of
/// this event — it is not this event, and is surfaced as [WsUnknown] rather
/// than decoded with a fabricated empty map that would crash the first
/// `ChatModel.fromJson`/`MessageModel.fromJson` call downstream.
WSEvent _parseChatMessageEvent(
  Map<String, dynamic> raw,
  String type,
  _ChatMessageEventFactory create,
) {
  final chatId = _chatIdOf(raw);
  if (chatId == null) return _unknown(type, raw, 'no chat_id');

  final payload = _payloadOf(raw);
  final chat = payload['chat'];
  final message = payload['message'];

  if (chat is! Map || message is! Map) {
    return _unknown(type, raw, 'missing chat/message payload');
  }

  return create(
    chatId: chatId,
    chat: chat.cast<String, dynamic>(),
    message: message.cast<String, dynamic>(),
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
