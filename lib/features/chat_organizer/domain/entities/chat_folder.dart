import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';

/// How a folder's rules add up.
enum FolderMatchMode {
  /// Every rule has to hold — the narrowing default.
  all('all'),

  /// Any one rule is enough.
  any('any');

  const FolderMatchMode(this.wire);

  final String wire;

  static FolderMatchMode fromWire(String? value) =>
      value == FolderMatchMode.any.wire
      ? FolderMatchMode.any
      : FolderMatchMode.all;
}

/// A tab over the chat list, defined by what it keeps rather than by what
/// someone dragged into it.
class ChatFolder extends Equatable {
  const ChatFolder({
    required this.id,
    required this.rules,
    this.preset,
    this.title,
    this.iconKey = defaultIconKey,
    this.matchMode = FolderMatchMode.all,
  });

  /// A ready-made folder, rules and icon included.
  factory ChatFolder.fromPreset(FolderPreset preset) => ChatFolder(
    id: preset.folderId,
    preset: preset,
    rules: preset.rules,
    iconKey: preset.iconKey,
  );

  static const String defaultIconKey = 'folder';

  /// How many folders one device can hold. Nothing technical forces a cap;
  /// past this the tab strip stops being a strip and starts being a list.
  static const int maxFolders = 10;

  static const int maxTitleLength = 24;

  final String id;

  /// Set when this folder came from [FolderPreset] and still matches it.
  /// Editing a preset drops this, because what is on screen is no longer
  /// what the preset says.
  final FolderPreset? preset;

  /// The user's name for the folder. Null on presets, whose name is
  /// translated at draw time.
  final String? title;

  final String iconKey;

  final List<FolderRule> rules;

  final FolderMatchMode matchMode;

  bool get isPreset => preset != null;

  /// A folder with no rules would swallow the whole list, so it never
  /// matches anything and the editor refuses to save one.
  bool matches(ChatEntity chat, ChatRuleContext context) {
    if (rules.isEmpty) return false;

    return switch (matchMode) {
      FolderMatchMode.all => rules.every((r) => r.evaluate(chat, context)),
      FolderMatchMode.any => rules.any((r) => r.evaluate(chat, context)),
    };
  }

  ChatFolder copyWith({
    String? id,
    String? title,
    String? iconKey,
    List<FolderRule>? rules,
    FolderMatchMode? matchMode,
    FolderPreset? preset,
    bool clearPreset = false,
  }) {
    return ChatFolder(
      id: id ?? this.id,
      preset: clearPreset ? null : (preset ?? this.preset),
      title: title ?? this.title,
      iconKey: iconKey ?? this.iconKey,
      rules: rules ?? this.rules,
      matchMode: matchMode ?? this.matchMode,
    );
  }

  @override
  List<Object?> get props => [id, preset, title, iconKey, rules, matchMode];
}
