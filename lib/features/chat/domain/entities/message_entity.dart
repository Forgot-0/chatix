import 'package:equatable/equatable.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';

/// `MessageDTO.type` / `SendMessageRequest.message_type` (api-docs §6.4).
enum MessageType {
  text,
  image,
  file,
  system,
  reply,
  forward;

  String get wire => name;

  static MessageType fromWire(String? value) {
    return MessageType.values.firstWhere(
      (t) => t.name == value,
      // `SendMessageRequest.message_type` defaults to "text" server-side
      // (api-docs §6.4); mirror that for unknown/missing values.
      orElse: () => MessageType.text,
    );
  }
}

/// `MessageDTO` (api-docs §6.4).
///
/// [replyTo] and [forwardedFrom] are the same `MessageDTO` shape nested one
/// level deep, so they are typed as [MessageEntity] here. The backend does
/// not recurse indefinitely — a reply-to-a-reply arrives with its own
/// `reply_to` already `null` — so rendering a quoted preview never needs a
/// depth guard, but it must also not assume the nested object carries its
/// own nested objects.
///
/// ⚠️ The three flat `forwarded_from_*` ids and the nested [forwardedFrom]
/// object are *both* present on a forward: the ids survive even when the
/// source message/chat is no longer readable by the caller, in which case
/// the nested object comes back `null`. Prefer the nested object for
/// rendering and fall back to the ids for "message unavailable" states.
class MessageEntity extends Equatable {
  final String id;
  final String chatId;

  /// Per-chat monotonic sequence number. This — not [createdAt] — is the
  /// cursor for pagination (`cursor_message_seq`), for `messages/context/`
  /// (`target_seq`) and for read receipts (`MarkReadRequest.message_seq`).
  final int seq;

  /// `null` for `system` messages, which have no human author.
  final int? authorId;

  final MessageType type;

  /// `null` is legitimate for an attachment-only message (caption omitted).
  final String? content;

  final String? replyToId;
  final String? forwardedFromChatId;
  final String? forwardedFromMessageId;

  /// ⚠️ A **string** on the wire, unlike every other user id in the API
  /// (api-docs §6.4 types it `string | null`, while `author_id` is a number).
  /// Kept as `String?` deliberately — parsing it to `int` here would hide
  /// that inconsistency and break the day the backend sends a non-numeric
  /// value.
  final String? forwardedFromAuthorId;

  final bool isEdited;
  final DateTime createdAt;
  final List<AttachmentEntity> attachments;

  /// The quoted original when this message is a reply (see class doc).
  final MessageEntity? replyTo;

  /// The original when this message is a forward (see class doc).
  final MessageEntity? forwardedFrom;

  const MessageEntity({
    required this.id,
    required this.chatId,
    required this.seq,
    required this.authorId,
    required this.type,
    required this.content,
    required this.replyToId,
    required this.forwardedFromChatId,
    required this.forwardedFromMessageId,
    required this.forwardedFromAuthorId,
    required this.isEdited,
    required this.createdAt,
    this.attachments = const [],
    this.replyTo,
    this.forwardedFrom,
  });

  /// True when this message was forwarded from somewhere, regardless of
  /// whether the source is still readable (see the ⚠️ in the class doc).
  bool get isForward =>
      forwardedFromMessageId != null || forwardedFrom != null;

  bool get isReply => replyToId != null || replyTo != null;

  /// True while any attachment is still being processed by the backend, so
  /// the bubble should show a spinner instead of a broken thumbnail
  /// (api-docs §6.5).
  bool get hasPendingAttachments => attachments.any(
    (a) => a.attachmentStatus == AttachmentStatus.pending,
  );

  /// Returns a copy with the given fields replaced.
  ///
  /// Added for the realtime layer (api-docs §7): a `message_deleted` event
  /// carries only `{message_id, seq, deleted_by}`, so rendering the message as
  /// a tombstone means clearing [content] and [attachments] on the copy the
  /// screen already holds — there is nothing left to re-fetch, since the
  /// message is gone server-side.
  ///
  /// ⚠️ [content] is cleared through [clearContent], not by passing `null`:
  /// `null` content is a legitimate value (an attachment-only message with no
  /// caption), so it cannot double as "leave unchanged".
  MessageEntity copyWith({
    String? id,
    String? chatId,
    int? seq,
    int? authorId,
    MessageType? type,
    String? content,
    String? replyToId,
    String? forwardedFromChatId,
    String? forwardedFromMessageId,
    String? forwardedFromAuthorId,
    bool? isEdited,
    DateTime? createdAt,
    List<AttachmentEntity>? attachments,
    MessageEntity? replyTo,
    MessageEntity? forwardedFrom,
    bool clearContent = false,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      seq: seq ?? this.seq,
      authorId: authorId ?? this.authorId,
      type: type ?? this.type,
      content: clearContent ? null : (content ?? this.content),
      replyToId: replyToId ?? this.replyToId,
      forwardedFromChatId: forwardedFromChatId ?? this.forwardedFromChatId,
      forwardedFromMessageId:
          forwardedFromMessageId ?? this.forwardedFromMessageId,
      forwardedFromAuthorId:
          forwardedFromAuthorId ?? this.forwardedFromAuthorId,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
      attachments: attachments ?? this.attachments,
      replyTo: replyTo ?? this.replyTo,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
    );
  }

  @override
  List<Object?> get props => [
    id,
    chatId,
    seq,
    authorId,
    type,
    content,
    replyToId,
    forwardedFromChatId,
    forwardedFromMessageId,
    forwardedFromAuthorId,
    isEdited,
    createdAt,
    attachments,
    replyTo,
    forwardedFrom,
  ];
}
