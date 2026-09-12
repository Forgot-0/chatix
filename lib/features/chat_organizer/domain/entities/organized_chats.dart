import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';

/// The chat list cut into the three blocks it is drawn as.
///
/// Order inside each block is the order the server sent — `last_activity_at`
/// descending with the chat id breaking ties (api-docs §5.2). Nothing is
/// re-sorted here: pinning lifts a chat out of one block into another, it
/// does not reshuffle what is left.
class OrganizedChats {
  const OrganizedChats({
    required this.pinned,
    required this.active,
    required this.archived,
  });

  final List<ChatEntity> pinned;
  final List<ChatEntity> active;
  final List<ChatEntity> archived;

  bool get hasArchive => archived.isNotEmpty;

  bool get isEmpty => pinned.isEmpty && active.isEmpty && archived.isEmpty;

  /// Everything the reader is meant to act on, in the order it is drawn.
  List<ChatEntity> get visible => [...pinned, ...active];

  /// What the archive row's badge says. A silenced chat does not add to it —
  /// the point of silencing one is that it stops asking for attention.
  int unreadInArchive(Set<String> mutedChatIds) {
    var total = 0;
    for (final chat in archived) {
      if (mutedChatIds.contains(chat.id)) continue;
      total += chat.unreadCount ?? 0;
    }
    return total;
  }
}

/// Splits [chats] into the pinned zone, the list and the archive.
///
/// [folder], when given, narrows the first two: the archive is what you put
/// away, and a tab should not hide half of it. Archiving wins over pinning,
/// so a chat that is somehow both ends up only in the archive.
OrganizedChats organizeChats({
  required List<ChatEntity> chats,
  required ChatOrganizerData organizer,
  required ChatRuleContext context,
  ChatFolder? folder,
}) {
  final pinned = <ChatEntity>[];
  final active = <ChatEntity>[];
  final archived = <ChatEntity>[];

  for (final chat in chats) {
    if (organizer.isArchived(chat.id)) {
      archived.add(chat);
      continue;
    }

    if (folder != null && !folder.matches(chat, context)) continue;

    if (organizer.isPinned(chat.id)) {
      pinned.add(chat);
    } else {
      active.add(chat);
    }
  }

  return OrganizedChats(pinned: pinned, active: active, archived: archived);
}

/// How much unread each folder is sitting on, keyed by folder id.
///
/// Archived and silenced chats do not count: neither is asking to be read,
/// and a tab that lights up for them would be lying about what tapping it
/// shows.
Map<String, int> folderUnreadCounts({
  required List<ChatEntity> chats,
  required ChatOrganizerData organizer,
  required ChatRuleContext context,
  Set<String> mutedChatIds = const <String>{},
}) {
  final counts = <String, int>{};

  for (final folder in organizer.folders) {
    var total = 0;

    for (final chat in chats) {
      final unread = chat.unreadCount ?? 0;
      if (unread == 0) continue;
      if (organizer.isArchived(chat.id)) continue;
      if (mutedChatIds.contains(chat.id)) continue;
      if (!folder.matches(chat, context)) continue;
      total += unread;
    }

    counts[folder.id] = total;
  }

  return counts;
}
