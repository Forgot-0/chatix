import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';

/// The chat list cut into the three groups it is drawn as.
///
/// Order inside each group is the order the server sent — `last_activity_at`
/// descending with the chat id breaking ties (api-docs §5.2). Nothing is
/// re-sorted here: pinning lifts a chat out of one group into another, it does
/// not reshuffle what is left.
class ChatListSections {
  const ChatListSections({
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
  int unreadInArchive(ChatLocalPrefs prefs) {
    var total = 0;
    for (final chat in archived) {
      if (prefs.isMuted(chat.id)) continue;
      total += chat.unreadCount ?? 0;
    }
    return total;
  }
}

/// Splits [chats] by what this device has been told about them.
///
/// Archiving wins over pinning: a chat someone pinned and later archived
/// belongs in the archive, not at the top of the list it was archived out of.
ChatListSections splitChatsForList(
  List<ChatEntity> chats,
  ChatLocalPrefs prefs,
) {
  final pinned = <ChatEntity>[];
  final active = <ChatEntity>[];
  final archived = <ChatEntity>[];

  for (final chat in chats) {
    if (prefs.isArchived(chat.id)) {
      archived.add(chat);
    } else if (prefs.isPinned(chat.id)) {
      pinned.add(chat);
    } else {
      active.add(chat);
    }
  }

  return ChatListSections(pinned: pinned, active: active, archived: archived);
}
