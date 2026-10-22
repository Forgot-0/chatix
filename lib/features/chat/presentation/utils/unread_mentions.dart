import 'dart:math' as math;

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/mention_syntax.dart';
import 'package:chatix/features/chat/presentation/utils/message_linkifier.dart';

/// Unread `@`-mentions of the reader, worked out from message text alone.
///
/// The API has no mention entities and no unread-mention counter: a message
/// is plain `content` (api-docs §5.4) and a chat row carries `unread_count`
/// and nothing about what is in those messages (§5.2). So the only mentions
/// a chat row can know about are the ones in messages this device has
/// actually seen — the row's own `last_message`, whatever arrived over the
/// socket, what is in the message cache. A mention further back than that is
/// not known, and the row never claims one it has not read.
abstract final class UnreadMentions {
  /// Whether [content] mentions [handle], found the way the bubble finds it
  /// ([MessageLinkifier]): `@` at the start of a word, the handle compared
  /// without regard to case, and a full stop after it handed back to the
  /// sentence. `@annabel` does not mention `ann`.
  static bool mentions(String? content, String handle) {
    if (content == null || !content.contains('@')) return false;

    final needle = handle.toLowerCase();
    final spans = MessageLinkifier.parse(
      content,
      isKnownMention: (candidate) => candidate.toLowerCase() == needle,
    );

    return spans.any(
      (span) => span is LinkSpan && span.kind == MessageLinkKind.mention,
    );
  }

  /// The highest `seq` among [messages] that mentions [handle], written by
  /// somebody other than [myUserId]. Null when none does, or when [handle]
  /// is one no message could mention so that it reads back
  /// ([MentionSyntax.isMentionable]).
  static int? newestMentionSeq(
    Iterable<MessageEntity?> messages, {
    required int myUserId,
    required String handle,
  }) {
    if (!MentionSyntax.isMentionable(handle)) return null;

    int? newest;
    for (final message in messages) {
      if (message == null || message.authorId == myUserId) continue;
      if (newest != null && message.seq <= newest) continue;
      if (mentions(message.content, handle)) newest = message.seq;
    }
    return newest;
  }

  /// How far the reader has read [chat], erring towards "further".
  ///
  /// `last_read` is the server's word for it, but a row patched in realtime
  /// keeps the old one while its `unread_count` moves on. Counting back from
  /// the newest `seq` by the unread count is never short of the truth either
  /// — gaps left by deleted messages only push it later — so the larger of
  /// the two is used: a mention wrongly taken for read costs a badge, one
  /// wrongly taken for unread sends the reader looking for nothing.
  static int readUpTo(ChatEntity chat) {
    final unread = chat.unreadCount ?? 0;
    final latest = math.max(chat.seqCounter, chat.lastMessage?.seq ?? 0);
    final counted = latest - unread;

    final reported = chat.lastRead?.lastReadMessageSeq;
    return reported == null ? counted : math.max(reported, counted);
  }

  /// Whether a mention at [mentionSeq] is still waiting in [chat].
  static bool isUnread(ChatEntity chat, int? mentionSeq) {
    if (mentionSeq == null) return false;
    if ((chat.unreadCount ?? 0) <= 0) return false;
    return mentionSeq > readUpTo(chat);
  }
}
