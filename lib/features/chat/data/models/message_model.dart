import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/chat/data/models/attachment_model.dart';
import 'package:chatix/features/chat/data/models/chat_profile_model.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

part 'message_model.g.dart';

/// `MessageDTO` (api-docs §6.4).
///
/// ⚠️ This model is **self-referential**: [replyTo] and [forwardedFrom] are
/// `MessageModel?`. json_serializable handles that fine (it emits a recursive
/// call to `MessageModel.fromJson`), and so does [toEntity] — the backend
/// nests only one level, so the recursion terminates on real payloads.
///
/// [type] and [createdAt] stay as wire strings and are converted in
/// [toEntity], matching the rest of the module's model↔entity boundary.
///
/// ⚠️ [forwardedFromAuthorId] is an `int?` — api-docs §6.4 types it
/// `number | null`, like every other user id in the API. It used to be
/// documented as a `string`, and the model followed; both have been corrected.
@JsonSerializable(fieldRename: FieldRename.snake)
class MessageModel extends Equatable {
  final String id;
  final String chatId;
  final int seq;
  final int? authorId;
  final String type;
  final String? content;
  final String? replyToId;
  final String? forwardedFromChatId;
  final String? forwardedFromMessageId;
  final int? forwardedFromAuthorId;
  final bool isEdited;
  final String createdAt;

  @JsonKey(defaultValue: <AttachmentModel>[])
  final List<AttachmentModel> attachments;

  final MessageModel? replyTo;
  final MessageModel? forwardedFrom;

  /// `MessageDTO.profile` (api-docs §6.4) — author's denormalized profile,
  /// nullable (system messages have no author).
  final ChatProfileModel? profile;

  const MessageModel({
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
    required this.attachments,
    this.replyTo,
    this.forwardedFrom,
    this.profile,
  });

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
    profile,
  ];

  factory MessageModel.fromJson(Map<String, dynamic> json) =>
      _$MessageModelFromJson(json);

  Map<String, dynamic> toJson() => _$MessageModelToJson(this);
}

extension MessageModelX on MessageModel {
  MessageEntity toEntity() {
    return MessageEntity(
      id: id,
      chatId: chatId,
      seq: seq,
      authorId: authorId,
      type: MessageType.fromWire(type),
      content: content,
      replyToId: replyToId,
      forwardedFromChatId: forwardedFromChatId,
      forwardedFromMessageId: forwardedFromMessageId,
      forwardedFromAuthorId: forwardedFromAuthorId,
      isEdited: isEdited,
      createdAt: DateTime.parse(createdAt),
      attachments: attachments.map((a) => a.toEntity()).toList(),
      replyTo: replyTo?.toEntity(),
      forwardedFrom: forwardedFrom?.toEntity(),
      profile: profile?.toEntity(),
    );
  }
}

/// `MessagesDTO` (api-docs §6.4) — cursor-paginated message page, shared by
/// `GET messages/` and `GET messages/context/`.
@JsonSerializable(fieldRename: FieldRename.snake)
class MessagesModel extends Equatable {
  @JsonKey(defaultValue: <MessageModel>[])
  final List<MessageModel> messages;
  final int? nextCursor;
  final bool hasNext;

  const MessagesModel({
    required this.messages,
    required this.nextCursor,
    required this.hasNext,
  });

  @override
  List<Object?> get props => [messages, nextCursor, hasNext];

  factory MessagesModel.fromJson(Map<String, dynamic> json) =>
      _$MessagesModelFromJson(json);

  Map<String, dynamic> toJson() => _$MessagesModelToJson(this);
}
