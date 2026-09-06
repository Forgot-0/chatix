library;

import 'dart:convert';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/ws_event.dart';

WSEvent parseWsEvent(Map<String, dynamic> raw) {
  final type = raw['type'];
  if (type is! String || type.isEmpty) {
    Logger.warning('WS frame without a "type" field: ${raw.keys.toList()}');
    return WsUnknown(type: '<missing>', raw: raw);
  }

  try {
    return switch (type) {
      'ws.ready' => _parseReady(raw),
      'ws.subscribed' => _parseSubscribed(raw),
      'ws.unsubscribed' => _parseUnsubscribed(raw),
      'ws.history' => _parseHistory(raw),
      'ws.pong' => const WsPong(),
      'ws.ping' => _parsePing(raw),
      'ws.error' => _parseError(raw),

      'new_message' => _parseNewMessage(raw),
      'message_edited' => _parseMessageEdited(raw),
      'message_deleted' => _parseMessageDeleted(raw),
      'messages_read' => _parseMessagesRead(raw),

      ReactionUpdated.wireType ||
      ReactionUpdated.legacyWireType => _parseReactionUpdated(raw),

      'member_joined' => _parseMemberJoined(raw),
      'member_left' => _parseMemberLeft(raw),
      'member_kick' => _parseMemberKick(raw),
      'member_banned' => _parseMemberBanned(raw),
      'chat_created' => _parseChatCreated(raw),
      'chat_updated' => _parseChatUpdated(raw),
      'chat_deleted' => _parseChatDeleted(raw),

      'attachment_success' => _parseAttachmentSuccess(raw),

      _ when WsUnimplementedEvent.types.contains(type) => WsUnimplementedEvent(
        type,
        chatId: _chatIdOf(raw),
        payload: _payloadOf(raw),
      ),

      _ => _unknown(type, raw, 'unrecognised type'),
    };
  } catch (error, stackTrace) {
    Logger.error('WS frame "$type" could not be parsed', error, stackTrace);
    return WsUnknown(type: type, raw: raw);
  }
}

WSEvent parseWsFrame(dynamic frame) {
  final String text;
  switch (frame) {
    case String s:
      text = s;
    case List<int> bytes:
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

WSEvent _parseReady(Map<String, dynamic> raw) {
  final payload = _payloadOf(raw);
  final reconnect = payload['reconnect'];
  final reconnectMap = reconnect is Map ? reconnect.cast<String, dynamic>() : const <String, dynamic>{};

  return WsReady(
    connectionId: _asString(payload['connection_id']) ?? '',
    gatewayId: _asString(payload['gateway_id']) ?? '',
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

WSEvent _parsePing(Map<String, dynamic> raw) {
  return WsPing(
    connectionId: _asString(raw['connection_id']),
    ts: _asDate(raw['ts']),
  );
}

WSEvent _parseError(Map<String, dynamic> raw) {
  final code = _asString(raw['code']);
  final detail = _asString(raw['detail']);
  final ts = _asDate(raw['ts']);

  if (code == 'NOT_CHAT_MEMBER') {
    return WsErrorNotChatMember(code: code!, ts: ts, detail: detail);
  }

  if (code == 'BAD_COMMAND' || code == 'BAD_FRAME') {
    return WsErrorBadCommand(code: code!, detail: detail ?? '', ts: ts);
  }

  if (code != null) {
    Logger.warning('ws.error with undocumented code "$code": $detail');
    return WsErrorBadCommand(code: code, detail: detail ?? '', ts: ts);
  }

  return _unknown('ws.error', raw, 'no code');
}

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
    eventName: _asString(payload['event_name']) ?? _asString(raw['event_name']),
    eventId: _asString(payload['event_id']) ?? _asString(raw['event_id']),
    ts: _asDate(raw['ts']),
  );
}

Map<String, dynamic> _deltaOf(Map<String, dynamic> raw) {
  final event = _payloadOf(raw)['event'];
  if (event is Map) return event.cast<String, dynamic>();
  return const {};
}

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

  final reaction = payload['reaction'];
  if (reaction is! Map) {
    return _unknown(ReactionUpdated.wireType, raw, 'no reaction snapshot');
  }
  final reactionMap = reaction.cast<String, dynamic>();

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

Map<String, dynamic> _payloadOf(Map<String, dynamic> raw) {
  final payload = raw['payload'];
  if (payload is Map) return payload.cast<String, dynamic>();
  return const {};
}

String? _chatIdOf(Map<String, dynamic> raw) {
  return _asString(raw['channel']) ??
      _asString(raw['chat_id']) ??
      _asString(_payloadOf(raw)['chat_id']);
}

String? _asString(Object? value) => value is String ? value : null;

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is double) {
    return value == value.roundToDouble() ? value.toInt() : null;
  }
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalised = value.toLowerCase();
    if (normalised == 'true') return true;
    if (normalised == 'false') return false;
  }
  return null;
}

DateTime? _asDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

WsUnknown _unknown(String type, Map<String, dynamic> raw, String reason) {
  Logger.warning('WS frame "$type" ignored ($reason): $raw');
  return WsUnknown(type: type, raw: raw);
}
