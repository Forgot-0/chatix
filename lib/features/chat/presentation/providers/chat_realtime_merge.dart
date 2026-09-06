import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';

abstract final class ChatRealtimeMerge {

  static List<MessageEntity> upsertMessage(
    List<MessageEntity> messages,
    MessageEntity message,
  ) {
    final result = <MessageEntity>[];
    var inserted = false;

    for (final existing in messages) {
      if (existing.id == message.id) continue;

      if (!inserted && message.seq > existing.seq) {
        result.add(message);
        inserted = true;
      }
      result.add(existing);
    }

    if (!inserted) result.add(message);

    return result;
  }

  static List<MessageEntity> applyMessageDeleted(
    List<MessageEntity> messages,
    String messageId, {
    bool asTombstone = false,
  }) {
    if (!asTombstone) {
      return messages.where((m) => m.id != messageId).toList();
    }

    return [
      for (final m in messages)
        if (m.id == messageId)
          m.copyWith(clearContent: true, attachments: const [])
        else
          m,
    ];
  }

  static int? highestSeq(List<MessageEntity> messages) {
    int? highest;
    for (final m in messages) {
      if (highest == null || m.seq > highest) highest = m.seq;
    }
    return highest;
  }

  static ChatEntity applyNewMessageToRow(
    ChatEntity chat,
    MessageEntity message, {
    required DateTime? ts,
    required bool isOpen,
    required bool isOwn,
  }) {
    final shouldBump = !isOpen && !isOwn;
    final current = chat.unreadCount;

    return chat.copyWith(
      seqCounter: message.seq > chat.seqCounter ? message.seq : chat.seqCounter,
      lastActivityAt: ts ?? DateTime.now(),
      unreadCount: shouldBump && current != null ? current + 1 : current,
    );
  }

  static ChatEntity applyChatUpdated(
    ChatEntity chat, {
    String? name,
    String? description,
    bool? isPublic,
    bool? adminOnly,
    int? slowModeSeconds,
    Map<String, bool>? permissions,
    ChatReactionsMode? reactionsMode,
    List<String>? allowedReactions,
  }) {
    return chat.copyWith(
      name: name,
      description: description,
      isPublic: isPublic,
      adminOnly: adminOnly,
      slowModeSeconds: slowModeSeconds,
      permissions: permissions,
      reactionsMode: reactionsMode,
      allowedReactions: allowedReactions,
    );
  }

  static List<MessageEntity> applyReactionSnapshot(
    List<MessageEntity> messages,
    String messageId,
    List<ReactionGroupEntity> groups, {
    int? actorId,
    int? myUserId,
  }) {
    return [
      for (final message in messages)
        if (message.id == messageId)
          message.copyWith(
            reactions: message.reactionSummary
                .applySnapshot(groups, actorId: actorId, myUserId: myUserId)
                .groups,
          )
        else
          message,
    ];
  }

  static List<MessageEntity> setReactionGroups(
    List<MessageEntity> messages,
    String messageId,
    List<ReactionGroupEntity> groups,
  ) {
    return [
      for (final message in messages)
        if (message.id == messageId)
          message.copyWith(reactions: groups)
        else
          message,
    ];
  }

  static List<ChatEntity> sortByActivity(List<ChatEntity> chats) {
    final sorted = [...chats]..sort((a, b) {
      final aAt = a.lastActivityAt;
      final bAt = b.lastActivityAt;
      if (aAt == null && bAt == null) return 0;
      if (aAt == null) return 1;
      if (bAt == null) return -1;
      return bAt.compareTo(aAt);
    });
    return sorted;
  }

  static List<ChatEntity> removeChat(List<ChatEntity> chats, String chatId) {
    return chats.where((c) => c.id != chatId).toList();
  }

  static List<ChatEntity> adjustMemberCount(
    List<ChatEntity> chats,
    String chatId,
    int delta,
  ) {
    return [
      for (final c in chats)
        if (c.id == chatId)
          c.copyWith(
            memberCount: (c.memberCount + delta) < 0 ? 0 : c.memberCount + delta,
          )
        else
          c,
    ];
  }
}
