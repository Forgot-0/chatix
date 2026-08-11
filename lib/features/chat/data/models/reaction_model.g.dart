// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reaction_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReactionSummaryModel _$ReactionSummaryModelFromJson(
  Map<String, dynamic> json,
) => ReactionSummaryModel(
  emoji: json['emoji'] as String,
  count: (json['count'] as num).toInt(),
  reactedByMe: json['reacted_by_me'] as bool? ?? false,
);

Map<String, dynamic> _$ReactionSummaryModelToJson(
  ReactionSummaryModel instance,
) => <String, dynamic>{
  'emoji': instance.emoji,
  'count': instance.count,
  'reacted_by_me': instance.reactedByMe,
};

ReactionUserModel _$ReactionUserModelFromJson(Map<String, dynamic> json) =>
    ReactionUserModel(
      userId: (json['user_id'] as num).toInt(),
      emoji: json['emoji'] as String,
    );

Map<String, dynamic> _$ReactionUserModelToJson(ReactionUserModel instance) =>
    <String, dynamic>{'user_id': instance.userId, 'emoji': instance.emoji};

MessageReactionsModel _$MessageReactionsModelFromJson(
  Map<String, dynamic> json,
) => MessageReactionsModel(
  messageId: json['message_id'] as String,
  summaries:
      (json['summaries'] as List<dynamic>?)
          ?.map((e) => ReactionSummaryModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  emoji: json['emoji'] as String?,
  users:
      (json['users'] as List<dynamic>?)
          ?.map((e) => ReactionUserModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  hasNext: json['has_next'] as bool? ?? false,
  nextUserId: (json['next_user_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$MessageReactionsModelToJson(
  MessageReactionsModel instance,
) => <String, dynamic>{
  'message_id': instance.messageId,
  'summaries': instance.summaries,
  'emoji': instance.emoji,
  'users': instance.users,
  'has_next': instance.hasNext,
  'next_user_id': instance.nextUserId,
};
