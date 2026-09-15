import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat/domain/entities/message_entity.dart';

/// What an outbox entry is trying to do.
///
/// Kept as data rather than as a closure because the queue outlives the
/// process that filled it: an entry is written to disk the moment it is
/// accepted and has to be reconstructible from nothing but its own JSON
/// after a restart.
sealed class OutboxOperation extends Equatable {
  const OutboxOperation();

  String get kind;

  Map<String, Object?> toJson();

  static OutboxOperation? fromJson(Map<String, dynamic> json) {
    return switch (json['kind']) {
      'send_message' => OutboxSendMessage.fromJson(json),
      'forward_message' => OutboxForwardMessage.fromJson(json),
      'reaction' => OutboxReaction.fromJson(json),
      'read' => OutboxRead.fromJson(json),
      _ => null,
    };
  }
}

/// `POST /chats/{chat_id}/messages/` (api-docs §5.4).
final class OutboxSendMessage extends OutboxOperation {
  const OutboxSendMessage({
    this.content,
    this.replyToId,
    this.messageType,
    this.uploadTokens = const [],
  });

  final String? content;
  final String? replyToId;
  final MessageType? messageType;
  final List<String> uploadTokens;

  @override
  String get kind => 'send_message';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'content': content,
    'reply_to_id': replyToId,
    'message_type': messageType?.wire,
    'upload_tokens': uploadTokens,
  };

  factory OutboxSendMessage.fromJson(Map<String, dynamic> json) {
    final type = json['message_type'];
    return OutboxSendMessage(
      content: json['content'] as String?,
      replyToId: json['reply_to_id'] as String?,
      messageType: type is String ? MessageType.fromWire(type) : null,
      uploadTokens: [
        for (final token in (json['upload_tokens'] as List? ?? const []))
          if (token is String) token,
      ],
    );
  }

  @override
  List<Object?> get props => [content, replyToId, messageType, uploadTokens];
}

/// `POST /chats/{chat_id}/messages/forward/` (api-docs §5.4).
final class OutboxForwardMessage extends OutboxOperation {
  const OutboxForwardMessage({
    required this.sourceChatId,
    required this.sourceMessageId,
    this.comment,
  });

  final String sourceChatId;
  final String sourceMessageId;
  final String? comment;

  @override
  String get kind => 'forward_message';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'source_chat_id': sourceChatId,
    'source_message_id': sourceMessageId,
    'comment': comment,
  };

  factory OutboxForwardMessage.fromJson(Map<String, dynamic> json) {
    return OutboxForwardMessage(
      sourceChatId: json['source_chat_id'] as String? ?? '',
      sourceMessageId: json['source_message_id'] as String? ?? '',
      comment: json['comment'] as String?,
    );
  }

  @override
  List<Object?> get props => [sourceChatId, sourceMessageId, comment];
}

/// Which of the four reaction endpoints (api-docs §5.7) an entry stands for.
enum OutboxReactionAction { set, remove, replace, clear }

final class OutboxReaction extends OutboxOperation {
  const OutboxReaction({
    required this.messageId,
    required this.action,
    this.emoji,
    this.emojis = const [],
  });

  final String messageId;
  final OutboxReactionAction action;

  /// The single emoji of a `set`/`remove`.
  final String? emoji;

  /// The whole set of a `replace`.
  final List<String> emojis;

  @override
  String get kind => 'reaction';

  @override
  Map<String, Object?> toJson() => {
    'kind': kind,
    'message_id': messageId,
    'action': action.name,
    'emoji': emoji,
    'emojis': emojis,
  };

  factory OutboxReaction.fromJson(Map<String, dynamic> json) {
    return OutboxReaction(
      messageId: json['message_id'] as String? ?? '',
      action: OutboxReactionAction.values.firstWhere(
        (a) => a.name == json['action'],
        orElse: () => OutboxReactionAction.set,
      ),
      emoji: json['emoji'] as String?,
      emojis: [
        for (final emoji in (json['emojis'] as List? ?? const []))
          if (emoji is String) emoji,
      ],
    );
  }

  @override
  List<Object?> get props => [messageId, action, emoji, emojis];
}

/// `POST /chats/{chat_id}/messages/read/` (api-docs §5.4).
///
/// Collapsing is the whole point of queueing this one: reading is a cursor,
/// not an event, so a hundred queued reports of the same chat are one report
/// of the furthest seq.
final class OutboxRead extends OutboxOperation {
  const OutboxRead({required this.seq});

  final int seq;

  @override
  String get kind => 'read';

  @override
  Map<String, Object?> toJson() => {'kind': kind, 'seq': seq};

  factory OutboxRead.fromJson(Map<String, dynamic> json) =>
      OutboxRead(seq: (json['seq'] as num?)?.toInt() ?? 0);

  @override
  List<Object?> get props => [seq];
}

/// One queued write, with everything needed to try it again later.
///
/// [id] doubles as the `Idempotency-Key` for the two operations that accept
/// one (api-docs §5.4): it is generated once, when the entry is created, and
/// survives every retry and every restart — which is exactly what stops a
/// "no network, try again on reconnect" retry from posting the message
/// twice. The key is cached server-side for 24 hours, so a retry inside that
/// window gets the first send's `MessageDTO` back rather than a duplicate.
class OutboxEntry extends Equatable {
  const OutboxEntry({
    required this.id,
    required this.chatId,
    required this.operation,
    required this.createdAt,
    this.attempts = 0,
    this.nextAttemptAt,
    this.failureMessage,
    this.needsAttention = false,
  });

  final String id;
  final String chatId;
  final OutboxOperation operation;
  final DateTime createdAt;

  /// How many times this entry has already been put on the wire.
  final int attempts;

  /// The earliest moment the queue may try again; null means "now".
  final DateTime? nextAttemptAt;

  /// Why the last attempt failed, for the row that offers Retry/Delete.
  final String? failureMessage;

  /// Set when automatic retrying has given up: either the server refused in
  /// a way that retrying cannot fix, or the backoff ran out of steps. The
  /// entry stays in the queue, but only a person can move it now.
  final bool needsAttention;

  /// How long to wait before attempt number [attempt] (1-based).
  ///
  /// Doubling, capped at a minute: long enough that a queue left running on
  /// a dead connection costs nothing, short enough that coming back into
  /// coverage is not a minute of silence — the queue is also kicked awake by
  /// the socket reconnecting, so the cap is a backstop, not the usual path.
  static Duration backoffFor(int attempt) {
    const schedule = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 20),
      Duration(seconds: 40),
      Duration(seconds: 60),
    ];
    if (attempt < 1) return schedule.first;
    return schedule[attempt > schedule.length ? schedule.length - 1 : attempt - 1];
  }

  /// After this many failed attempts the entry stops retrying itself.
  static const int maxAutomaticAttempts = 7;

  bool isDue(DateTime now) {
    if (needsAttention) return false;
    final at = nextAttemptAt;
    return at == null || !at.isAfter(now);
  }

  OutboxEntry copyWith({
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttemptAt = false,
    String? failureMessage,
    bool clearFailure = false,
    bool? needsAttention,
    OutboxOperation? operation,
  }) {
    return OutboxEntry(
      id: id,
      chatId: chatId,
      operation: operation ?? this.operation,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: clearNextAttemptAt
          ? null
          : (nextAttemptAt ?? this.nextAttemptAt),
      failureMessage: clearFailure
          ? null
          : (failureMessage ?? this.failureMessage),
      needsAttention: needsAttention ?? this.needsAttention,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'chat_id': chatId,
    'operation': operation.toJson(),
    'created_at': createdAt.toIso8601String(),
    'attempts': attempts,
    'next_attempt_at': nextAttemptAt?.toIso8601String(),
    'failure_message': failureMessage,
    'needs_attention': needsAttention,
  };

  /// Null when the stored row is from a schema this build does not know.
  static OutboxEntry? fromJson(Map<String, dynamic> json) {
    final rawOperation = json['operation'];
    if (rawOperation is! Map) return null;

    final operation = OutboxOperation.fromJson(
      Map<String, dynamic>.from(rawOperation),
    );
    if (operation == null) return null;

    final id = json['id'];
    final chatId = json['chat_id'];
    if (id is! String || chatId is! String) return null;

    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    if (createdAt == null) return null;

    return OutboxEntry(
      id: id,
      chatId: chatId,
      operation: operation,
      createdAt: createdAt,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAt: DateTime.tryParse(
        json['next_attempt_at'] as String? ?? '',
      ),
      failureMessage: json['failure_message'] as String?,
      needsAttention: json['needs_attention'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id,
    chatId,
    operation,
    createdAt,
    attempts,
    nextAttemptAt,
    failureMessage,
    needsAttention,
  ];
}
