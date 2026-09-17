import 'dart:convert';

import 'package:equatable/equatable.dart';

/// A push, read as defensively as api-docs §7.2 asks for.
///
/// `NotificationDTO.payload` is `Record<string, unknown>` — the backend does
/// not type it, and what lands in an FCM `data` map is whatever the sender put
/// there, flattened to strings. So nothing here is required, every field has
/// several spellings it will answer to, and a payload that carries only a chat
/// id still produces a usable message.
class PushMessage extends Equatable {
  const PushMessage({
    this.chatId,
    this.chatName,
    this.messageId,
    this.messageSeq,
    this.senderName,
    this.senderAvatarUrl,
    this.text,
    this.title,
    this.isMention = false,
    this.isSystem = false,
    this.eventId,
    this.sentAt,
    this.raw = const <String, dynamic>{},
  });

  final String? chatId;
  final String? chatName;
  final String? messageId;
  final int? messageSeq;
  final String? senderName;
  final String? senderAvatarUrl;
  final String? text;
  final String? title;

  /// Whether this message names the reader — the one thing the
  /// "mentions only" chat profile lets through.
  final bool isMention;

  /// A service notice rather than a chat message: it belongs to no chat and
  /// no per-chat profile applies to it.
  final bool isSystem;

  /// `payload.event_id` where the sender bothered to put one. WS delivery is
  /// at-least-once (api-docs §6) and push is no better, so the same message
  /// can arrive twice; this is what lets the second one be dropped.
  final String? eventId;

  final DateTime? sentAt;

  /// The payload as it arrived, kept so a tap can be resolved from the same
  /// data the notification was built from.
  final Map<String, dynamic> raw;

  /// Whether there is enough here to be worth drawing.
  ///
  /// A chat message needs its chat; a service notice needs something to say.
  /// A payload with neither is a push this build does not understand, and
  /// drawing an empty notification for it helps nobody.
  bool get isActionable =>
      chatId != null || title != null || text != null;

  /// What the shade bundles this under.
  String? get groupKey => chatId == null ? null : 'chat_$chatId';

  /// Stable per message, so the same push arriving twice replaces rather than
  /// stacks.
  String get notificationId {
    final id = messageId ?? eventId;
    if (id != null) return 'msg_$id';
    final seq = messageSeq;
    if (chatId != null && seq != null) return 'msg_${chatId}_$seq';
    if (chatId != null) return 'chat_$chatId';
    return 'system_${sentAt?.millisecondsSinceEpoch ?? 0}';
  }

  static PushMessage fromPayload(Map<String, dynamic> payload) {
    final flat = _flatten(payload);

    final chatId = _string(flat, const [
      'chat_id',
      'chatid',
      'chat',
      'chatId',
    ]);
    final type = _string(flat, const ['type', 'notification_type']);

    return PushMessage(
      chatId: chatId,
      chatName: _string(flat, const ['chat_name', 'chatname', 'chat_title']),
      messageId: _string(flat, const ['message_id', 'messageid', 'msg_id']),
      messageSeq: _int(flat, const ['message_seq', 'messageseq', 'seq']),
      senderName: _string(flat, const [
        'sender_name',
        'sendername',
        'sender',
        'author',
        'from',
        'username',
      ]),
      senderAvatarUrl: _string(flat, const [
        'sender_avatar_url',
        'sender_avatar',
        'avatar_url',
        'avatar',
      ]),
      text: _string(flat, const [
        'body',
        'text',
        'content',
        'preview',
        'message_text',
      ]),
      title: _string(flat, const ['title']),
      isMention: _bool(flat, const [
        'is_mention',
        'ismention',
        'mention',
        'mentioned',
      ]),
      isSystem: chatId == null || type == 'system',
      eventId: _string(flat, const ['event_id', 'eventid']),
      sentAt: _dateTime(flat, const ['created_at', 'sent_at', 'timestamp']),
      raw: payload,
    );
  }

  /// Pulls nested objects up to the top level.
  ///
  /// A payload can arrive as `{chat_id: …}`, as `{payload: {chat_id: …}}` or
  /// as `{data: {message: {chat_id: …}}}` depending on who assembled it, and
  /// none of those spellings is documented. Outer keys win over inner ones, so
  /// an explicit top-level value is never shadowed by a nested one.
  static Map<String, Object?> _flatten(Map<String, dynamic> source) {
    final flat = <String, Object?>{};

    void absorb(Map<Object?, Object?> map, int level) {
      for (final entry in map.entries) {
        final key = '${entry.key}'.toLowerCase();
        final value = entry.value;

        if (value is Map) {
          if (level < _maxDepth) absorb(value, level + 1);
          continue;
        }

        // Every value in an FCM `data` map is a string, so a nested object
        // arrives JSON-encoded rather than as a `Map`.
        if (value is String && level < _maxDepth) {
          final nested = _decodeObject(value);
          if (nested != null) {
            absorb(nested, level + 1);
            continue;
          }
        }

        flat.putIfAbsent(key, () => value);
      }
    }

    absorb(source, 0);
    return flat;
  }

  static const int _maxDepth = 3;

  static Map<Object?, Object?>? _decodeObject(String value) {
    final trimmed = value.trimLeft();
    if (!trimmed.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static String? _string(Map<String, Object?> flat, List<String> keys) {
    for (final key in keys) {
      final value = flat[key.toLowerCase()];
      if (value == null) continue;
      final text = '$value'.trim();
      if (text.isEmpty || text == 'null') continue;
      return text;
    }
    return null;
  }

  static int? _int(Map<String, Object?> flat, List<String> keys) {
    final raw = _string(flat, keys);
    if (raw == null) return null;
    final parsed = int.tryParse(raw) ?? double.tryParse(raw)?.toInt();
    if (parsed == null || parsed < 1) return null;
    return parsed;
  }

  static bool _bool(Map<String, Object?> flat, List<String> keys) {
    final raw = _string(flat, keys)?.toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  static DateTime? _dateTime(Map<String, Object?> flat, List<String> keys) {
    final raw = _string(flat, keys);
    if (raw == null) return null;

    // Digits first: `DateTime.parse` reads a bare run of digits as a date in
    // the compact ISO form and turns an epoch into a year in the hundred
    // thousands, so it never gets to see one.
    final epoch = int.tryParse(raw);
    if (epoch != null) {
      // Seconds or milliseconds — both spellings turn up in push payloads.
      return DateTime.fromMillisecondsSinceEpoch(
        epoch < 100000000000 ? epoch * 1000 : epoch,
      ).toLocal();
    }

    return DateTime.tryParse(raw)?.toLocal();
  }

  @override
  List<Object?> get props => [
    chatId,
    chatName,
    messageId,
    messageSeq,
    senderName,
    senderAvatarUrl,
    text,
    title,
    isMention,
    isSystem,
    eventId,
    sentAt,
  ];
}
