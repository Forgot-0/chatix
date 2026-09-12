import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_settings.dart';

/// Everything the organizer knows, in one value.
///
/// None of it is on the server: `/chats/` has no pin, archive or folder field
/// (api-docs §5.2), so this lives on the device and does not follow the
/// account to the next one. See `docs/BACKEND_GAPS.md`.
class ChatOrganizerData extends Equatable {
  const ChatOrganizerData({
    this.pinnedChatIds = const <String>{},
    this.archivedChatIds = const <String>{},
    this.folders = const <ChatFolder>[],
    this.settings = const OrganizerSettings(),
  });

  /// Insertion-ordered: the order chats were pinned in, which is what the
  /// limit is counted against.
  final Set<String> pinnedChatIds;

  final Set<String> archivedChatIds;

  /// In the order the tab strip draws them.
  final List<ChatFolder> folders;

  final OrganizerSettings settings;

  bool isPinned(String chatId) => pinnedChatIds.contains(chatId);

  bool isArchived(String chatId) => archivedChatIds.contains(chatId);

  bool get canPinMore => pinnedChatIds.length < OrganizerLimits.pinnedChats;

  ChatFolder? folderById(String? id) {
    if (id == null) return null;
    for (final folder in folders) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  ChatOrganizerData copyWith({
    Set<String>? pinnedChatIds,
    Set<String>? archivedChatIds,
    List<ChatFolder>? folders,
    OrganizerSettings? settings,
  }) {
    return ChatOrganizerData(
      pinnedChatIds: pinnedChatIds ?? this.pinnedChatIds,
      archivedChatIds: archivedChatIds ?? this.archivedChatIds,
      folders: folders ?? this.folders,
      settings: settings ?? this.settings,
    );
  }

  @override
  List<Object?> get props => [
    pinnedChatIds,
    archivedChatIds,
    folders,
    settings,
  ];
}
