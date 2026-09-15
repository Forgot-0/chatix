import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_settings.dart';

/// Everything the organizer knows, in one value.
///
/// Folders and the switches around them, and nothing else. Pins, the archive
/// and silenced chats used to live here too; they are fields on the chat row
/// now (`is_pinned`, `is_archived`, `is_muted_by_me`, api-docs §5.2) and
/// follow the account between devices. Folders still do not — there is no
/// folder resource in the API. See `docs/BACKEND_GAPS.md`.
class ChatOrganizerData extends Equatable {
  const ChatOrganizerData({
    this.folders = const <ChatFolder>[],
    this.settings = const OrganizerSettings(),
  });

  /// In the order the tab strip draws them.
  final List<ChatFolder> folders;

  final OrganizerSettings settings;

  ChatFolder? folderById(String? id) {
    if (id == null) return null;
    for (final folder in folders) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  ChatOrganizerData copyWith({
    List<ChatFolder>? folders,
    OrganizerSettings? settings,
  }) {
    return ChatOrganizerData(
      folders: folders ?? this.folders,
      settings: settings ?? this.settings,
    );
  }

  @override
  List<Object?> get props => [folders, settings];
}
