import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';

/// The chat list cut into the two blocks it is drawn as.
///
/// The archive is not one of them any more: `GET /chats/?archived=true` is a
/// set of its own with its own cursor (api-docs §5.2), so what is put away
/// is not in this list to be split out of it.
class OrganizedChats {
  const OrganizedChats({required this.pinned, required this.active});

  static const OrganizedChats empty = OrganizedChats(
    pinned: [],
    active: [],
  );

  /// Newest pin first, the order the server sends them in.
  final List<ChatEntity> pinned;

  final List<ChatEntity> active;

  bool get isEmpty => pinned.isEmpty && active.isEmpty;

  /// Everything the reader is meant to act on, in the order it is drawn.
  List<ChatEntity> get visible => [...pinned, ...active];
}

/// Splits [chats] into the pinned zone and the list below it.
///
/// [folder], when given, narrows both. A row that says it is archived is
/// dropped: the list should not be holding one, but a chat archived a
/// moment ago on this device is briefly still here, and it should leave the
/// screen the moment it is put away rather than on the next fetch.
OrganizedChats organizeChats({
  required List<ChatEntity> chats,
  required ChatRuleContext context,
  ChatFolder? folder,
}) {
  final pinned = <ChatEntity>[];
  final active = <ChatEntity>[];

  for (final chat in chats) {
    if (chat.isArchived) continue;
    if (folder != null && !folder.matches(chat, context)) continue;

    if (chat.isPinned) {
      pinned.add(chat);
    } else {
      active.add(chat);
    }
  }

  // `pinned_at DESC`, the order the server puts them in at the head of the
  // first page. Rows without a date keep the order they arrived in.
  pinned.sort((a, b) {
    final left = a.pinnedAt;
    final right = b.pinnedAt;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  });

  return OrganizedChats(pinned: pinned, active: active);
}

/// How much unread the archive is sitting on.
///
/// A silenced chat does not add to it — the point of silencing one is that
/// it stops asking for attention.
int unreadInArchive(List<ChatEntity> archived) {
  var total = 0;
  for (final chat in archived) {
    if (chat.isMutedByMe) continue;
    total += chat.unreadCount ?? 0;
  }
  return total;
}

/// How much unread each folder is sitting on, keyed by folder id.
///
/// Archived and silenced chats do not count: neither is asking to be read,
/// and a tab that lights up for them would be lying about what tapping it
/// shows.
Map<String, int> folderUnreadCounts({
  required List<ChatEntity> chats,
  required List<ChatFolder> folders,
  required ChatRuleContext context,
}) {
  final counts = <String, int>{};

  for (final folder in folders) {
    var total = 0;

    for (final chat in chats) {
      final unread = chat.unreadCount ?? 0;
      if (unread == 0) continue;
      if (chat.isArchived) continue;
      if (chat.isMutedByMe) continue;
      if (!folder.matches(chat, context)) continue;
      total += unread;
    }

    counts[folder.id] = total;
  }

  return counts;
}
