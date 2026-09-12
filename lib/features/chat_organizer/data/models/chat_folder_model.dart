import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:chatix/features/chat_organizer/data/models/folder_rule_model.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';

part 'chat_folder_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class ChatFolderModel extends Equatable {
  const ChatFolderModel({
    required this.id,
    required this.rules,
    this.preset,
    this.title,
    this.iconKey = ChatFolder.defaultIconKey,
    this.matchMode = 'all',
  });

  factory ChatFolderModel.fromJson(Map<String, dynamic> json) =>
      _$ChatFolderModelFromJson(json);

  factory ChatFolderModel.fromEntity(ChatFolder folder) {
    return ChatFolderModel(
      id: folder.id,
      preset: folder.preset?.wire,
      title: folder.title,
      iconKey: folder.iconKey,
      matchMode: folder.matchMode.wire,
      rules: folder.rules.map(FolderRuleModel.fromEntity).toList(),
    );
  }

  final String id;
  final String? preset;
  final String? title;
  final String iconKey;
  final String matchMode;
  final List<FolderRuleModel> rules;

  /// The folder this stands for, or null when nothing usable is left of it —
  /// a folder whose every rule came from a newer build would otherwise show
  /// up as a tab that matches the entire list.
  ChatFolder? toEntity() {
    final parsed = <FolderRuleModel>[...rules]
        .map((rule) => rule.toEntity())
        .nonNulls
        .toList();
    if (parsed.isEmpty) return null;

    return ChatFolder(
      id: id,
      preset: FolderPreset.fromWire(preset),
      title: title,
      iconKey: iconKey,
      matchMode: FolderMatchMode.fromWire(matchMode),
      rules: parsed,
    );
  }

  Map<String, dynamic> toJson() => _$ChatFolderModelToJson(this);

  @override
  List<Object?> get props => [id, preset, title, iconKey, matchMode, rules];
}
