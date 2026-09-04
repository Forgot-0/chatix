// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reaction_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReactionGroupModel _$ReactionGroupModelFromJson(Map<String, dynamic> json) =>
    ReactionGroupModel(
      emoji: json['emoji'] as String,
      count: (json['count'] as num).toInt(),
      version: (json['version'] as num?)?.toInt() ?? 0,
      reactedByMe: json['reacted_by_me'] as bool? ?? false,
      recentUserIds:
          (json['recent_user_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
    );

Map<String, dynamic> _$ReactionGroupModelToJson(ReactionGroupModel instance) =>
    <String, dynamic>{
      'emoji': instance.emoji,
      'count': instance.count,
      'version': instance.version,
      'reacted_by_me': instance.reactedByMe,
      'recent_user_ids': instance.recentUserIds,
    };

MessageReactionsModel _$MessageReactionsModelFromJson(
  Map<String, dynamic> json,
) => MessageReactionsModel(
  messageId: json['message_id'] as String,
  groups:
      (json['groups'] as List<dynamic>?)
          ?.map((e) => ReactionGroupModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  emoji: json['emoji'] as String?,
  users:
      (json['users'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      [],
  hasNext: json['has_next'] as bool? ?? false,
  nextUserId: (json['next_user_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$MessageReactionsModelToJson(
  MessageReactionsModel instance,
) => <String, dynamic>{
  'message_id': instance.messageId,
  'groups': instance.groups,
  'emoji': instance.emoji,
  'users': instance.users,
  'has_next': instance.hasNext,
  'next_user_id': instance.nextUserId,
};

ReactionUpdateModel _$ReactionUpdateModelFromJson(Map<String, dynamic> json) =>
    ReactionUpdateModel(
      messageId: json['message_id'] as String,
      chatId: json['chat_id'] as String,
      actorId: (json['actor_id'] as num).toInt(),
      action: json['action'] as String,
      groups:
          (json['groups'] as List<dynamic>?)
              ?.map(
                (e) => ReactionGroupModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );

Map<String, dynamic> _$ReactionUpdateModelToJson(
  ReactionUpdateModel instance,
) => <String, dynamic>{
  'message_id': instance.messageId,
  'chat_id': instance.chatId,
  'actor_id': instance.actorId,
  'action': instance.action,
  'groups': instance.groups,
};
