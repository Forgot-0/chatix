// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_folder_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatFolderModel _$ChatFolderModelFromJson(Map<String, dynamic> json) =>
    ChatFolderModel(
      id: json['id'] as String,
      rules: (json['rules'] as List<dynamic>)
          .map((e) => FolderRuleModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      preset: json['preset'] as String?,
      title: json['title'] as String?,
      iconKey: json['icon_key'] as String? ?? ChatFolder.defaultIconKey,
      matchMode: json['match_mode'] as String? ?? 'all',
    );

Map<String, dynamic> _$ChatFolderModelToJson(ChatFolderModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'preset': instance.preset,
      'title': instance.title,
      'icon_key': instance.iconKey,
      'match_mode': instance.matchMode,
      'rules': instance.rules.map((e) => e.toJson()).toList(),
    };
