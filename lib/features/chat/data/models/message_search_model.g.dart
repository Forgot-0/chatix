// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_search_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageSearchChatModel _$MessageSearchChatModelFromJson(
  Map<String, dynamic> json,
) => MessageSearchChatModel(
  id: json['id'] as String,
  type: json['type'] as String,
  name: json['name'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  avatarS3Key: json['avatar_s3_key'] as String?,
);

Map<String, dynamic> _$MessageSearchChatModelToJson(
  MessageSearchChatModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'name': instance.name,
  'avatar_url': instance.avatarUrl,
  'avatar_s3_key': instance.avatarS3Key,
};

MessageSearchItemModel _$MessageSearchItemModelFromJson(
  Map<String, dynamic> json,
) => MessageSearchItemModel(
  message: MessageModel.fromJson(json['message'] as Map<String, dynamic>),
  chat: json['chat'] == null
      ? null
      : MessageSearchChatModel.fromJson(json['chat'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MessageSearchItemModelToJson(
  MessageSearchItemModel instance,
) => <String, dynamic>{'message': instance.message, 'chat': instance.chat};

MessageSearchModel _$MessageSearchModelFromJson(Map<String, dynamic> json) =>
    MessageSearchModel(
      hasNext: json['has_next'] as bool,
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) =>
                    MessageSearchItemModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      nextMessageId: json['next_message_id'] as String?,
    );

Map<String, dynamic> _$MessageSearchModelToJson(MessageSearchModel instance) =>
    <String, dynamic>{
      'has_next': instance.hasNext,
      'items': instance.items,
      'next_message_id': instance.nextMessageId,
    };
