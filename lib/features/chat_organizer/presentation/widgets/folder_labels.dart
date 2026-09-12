import 'package:flutter/material.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The icons a folder can wear.
///
/// The domain stores the key, not the glyph: `IconData` is a Material type
/// and has no business in an entity that a server datasource might one day
/// have to serialise.
abstract final class FolderIcons {
  static const Map<String, IconData> byKey = <String, IconData>{
    'folder': Icons.folder_outlined,
    'unread': Icons.mark_chat_unread_outlined,
    'person': Icons.person_outline,
    'group': Icons.groups_outlined,
    'channel': Icons.campaign_outlined,
    'reply': Icons.reply_outlined,
    'star': Icons.star_outline,
    'work': Icons.work_outline,
    'tag': Icons.sell_outlined,
    'bolt': Icons.bolt_outlined,
  };

  static const List<String> keys = <String>[
    'folder',
    'unread',
    'person',
    'group',
    'channel',
    'reply',
    'star',
    'work',
    'tag',
    'bolt',
  ];

  static IconData resolve(String key) =>
      byKey[key] ?? byKey[ChatFolder.defaultIconKey]!;
}

String folderPresetTitle(FolderPreset preset, AppLocalizations l10n) {
  switch (preset) {
    case FolderPreset.unread:
      return l10n.folderPresetUnread;
    case FolderPreset.personal:
      return l10n.folderPresetPersonal;
    case FolderPreset.groups:
      return l10n.folderPresetGroups;
    case FolderPreset.channels:
      return l10n.folderPresetChannels;
    case FolderPreset.noReplyFromMe:
      return l10n.folderPresetNoReply;
  }
}

/// What the tab says. Presets are translated; a folder someone named keeps
/// the name they gave it.
String folderTitleOf(ChatFolder folder, AppLocalizations l10n) {
  final preset = folder.preset;
  if (preset != null) return folderPresetTitle(preset, l10n);

  final title = folder.title?.trim() ?? '';
  return title.isEmpty ? l10n.newFolder : title;
}

String chatTypeLabel(ChatType type, AppLocalizations l10n) {
  switch (type) {
    case ChatType.direct:
      return l10n.chatTypeDirect;
    case ChatType.group:
      return l10n.chatTypeGroup;
    case ChatType.supergroup:
      return l10n.chatTypeSuper;
    case ChatType.channel:
      return l10n.chatTypeChannel;
  }
}

/// One rule in a line, the way the editor and the folder list show it.
String folderRuleSummary(FolderRule rule, AppLocalizations l10n) {
  switch (rule) {
    case ChatTypeRule(:final types):
      final names = ChatType.values
          .where(types.contains)
          .map((type) => chatTypeLabel(type, l10n))
          .join(', ');
      return l10n.folderRuleChatTypeIn(names);

    case UnreadRule(:final expected):
      return expected ? l10n.folderRuleUnread : l10n.folderRuleRead;

    case PinnedRule(:final expected):
      return expected ? l10n.folderRulePinned : l10n.folderRuleNotPinned;

    case NoReplyFromMeRule(:final days):
      return l10n.folderRuleNoReplyDays(days);

    case MemberRule(:final label):
      final name = label?.trim() ?? '';
      return name.isEmpty
          ? l10n.folderRuleMember
          : l10n.folderRuleMemberNamed(name);
  }
}

IconData folderRuleIcon(FolderRuleKind kind) {
  switch (kind) {
    case FolderRuleKind.chatType:
      return Icons.category_outlined;
    case FolderRuleKind.unread:
      return Icons.mark_chat_unread_outlined;
    case FolderRuleKind.pinned:
      return Icons.push_pin_outlined;
    case FolderRuleKind.noReplyFromMe:
      return Icons.reply_outlined;
    case FolderRuleKind.member:
      return Icons.person_search_outlined;
  }
}

String folderRuleKindLabel(FolderRuleKind kind, AppLocalizations l10n) {
  switch (kind) {
    case FolderRuleKind.chatType:
      return l10n.folderRuleChatType;
    case FolderRuleKind.unread:
      return l10n.folderRuleUnread;
    case FolderRuleKind.pinned:
      return l10n.folderRulePinned;
    case FolderRuleKind.noReplyFromMe:
      return l10n.folderRuleNoReply;
    case FolderRuleKind.member:
      return l10n.folderRuleMember;
  }
}
