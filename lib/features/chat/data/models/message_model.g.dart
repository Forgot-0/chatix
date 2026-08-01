// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageModel _$MessageModelFromJson(Map<String, dynamic> json) => MessageModel(
  id: json['id'] as String,
  chatId: json['chat_id'] as String,
  seq: (json['seq'] as num).toInt(),
  authorId: (json['author_id'] as num?)?.toInt(),
  type: json['type'] as String,
  content: json['content'] as String?,
  replyToId: json['reply_to_id'] as String?,
  forwardedFromChatId: json['forwarded_from_chat_id'] as String?,
  forwardedFromMessageId: json['forwarded_from_message_id'] as String?,
  forwardedFromAuthorId: json['forwarded_from_author_id'] as String?,
  isEdited: json['is_edited'] as bool,
  createdAt: json['created_at'] as String,
  attachments:
      (json['attachments'] as List<dynamic>?)
          ?.map((e) => AttachmentModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  replyTo: json['reply_to'] == null
      ? null
      : MessageModel.fromJson(json['reply_to'] as Map<String, dynamic>),
  forwardedFrom: json['forwarded_from'] == null
      ? null
      : MessageModel.fromJson(json['forwarded_from'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MessageModelToJson(MessageModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chat_id': instance.chatId,
      'seq': instance.seq,
      'author_id': instance.authorId,
      'type': instance.type,
      'content': instance.content,
      'reply_to_id': instance.replyToId,
      'forwarded_from_chat_id': instance.forwardedFromChatId,
      'forwarded_from_message_id': instance.forwardedFromMessageId,
      'forwarded_from_author_id': instance.forwardedFromAuthorId,
      'is_edited': instance.isEdited,
      'created_at': instance.createdAt,
      'attachments': instance.attachments,
      'reply_to': instance.replyTo,
      'forwarded_from': instance.forwardedFrom,
    };

MessagesModel _$MessagesModelFromJson(Map<String, dynamic> json) =>
    MessagesModel(
      messages:
          (json['messages'] as List<dynamic>?)
              ?.map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: (json['next_cursor'] as num?)?.toInt(),
      hasNext: json['has_next'] as bool,
    );

Map<String, dynamic> _$MessagesModelToJson(MessagesModel instance) =>
    <String, dynamic>{
      'messages': instance.messages,
      'next_cursor': instance.nextCursor,
      'has_next': instance.hasNext,
    };
