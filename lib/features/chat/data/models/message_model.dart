import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/chat/data/models/attachment_model.dart';
import 'package:chatix/features/chat/data/models/chat_profile_model.dart';
import 'package:chatix/features/chat/data/models/reaction_model.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

part 'message_model.g.dart';

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

  @JsonKey(defaultValue: <ReactionGroupModel>[])
  final List<ReactionGroupModel> reactions;

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
    required this.reactions,
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
    reactions,
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
      reactions: reactions.map((r) => r.toEntity()).toList(),
    );
  }
}

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

extension MessageEntityX on MessageEntity {
  /// The DTO this message came from, so it can be written back down.
  ///
  /// The round trip has to be exact in both directions: a message is cached
  /// from whichever source produced it — a REST page, a `ws.history` replay,
  /// a `new_message` push — and read back into the same feed as the ones
  /// that never left memory. See [AttachmentEntityX.toModel] for the single
  /// field that is deliberately not kept.
  MessageModel toModel() => MessageModel(
    id: id,
    chatId: chatId,
    seq: seq,
    authorId: authorId,
    type: type.wire,
    content: content,
    replyToId: replyToId,
    forwardedFromChatId: forwardedFromChatId,
    forwardedFromMessageId: forwardedFromMessageId,
    forwardedFromAuthorId: forwardedFromAuthorId,
    isEdited: isEdited,
    createdAt: createdAt.toIso8601String(),
    attachments: [for (final a in attachments) a.toModel()],
    replyTo: replyTo?.toModel(),
    forwardedFrom: forwardedFrom?.toModel(),
    profile: profile?.toModel(),
    reactions: [for (final r in reactions) r.toModel()],
  );
}
