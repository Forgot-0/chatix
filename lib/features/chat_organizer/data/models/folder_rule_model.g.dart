// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder_rule_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FolderRuleModel _$FolderRuleModelFromJson(Map<String, dynamic> json) =>
    FolderRuleModel(
      type: json['type'] as String,
      chatTypes: (json['chat_types'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      expected: json['expected'] as bool?,
      days: (json['days'] as num?)?.toInt(),
      userId: (json['user_id'] as num?)?.toInt(),
      label: json['label'] as String?,
    );

Map<String, dynamic> _$FolderRuleModelToJson(FolderRuleModel instance) =>
    <String, dynamic>{
      'type': instance.type,
      'chat_types': instance.chatTypes,
      'expected': instance.expected,
      'days': instance.days,
      'user_id': instance.userId,
      'label': instance.label,
    };
