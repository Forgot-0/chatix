import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';

/// What a rule needs to know that a single [ChatEntity] cannot answer.
///
/// Who "me" is decides whether the last message counts as a reply; the clock
/// decides how old that message is; and pinning is a device-local fact the
/// chat row knows nothing about. Everything here is passed in so the rules
/// themselves stay pure functions of their inputs.
class ChatRuleContext extends Equatable {
  const ChatRuleContext({
    required this.now,
    this.myUserId,
    this.pinnedChatIds = const <String>{},
  });

  final DateTime now;

  final int? myUserId;

  final Set<String> pinnedChatIds;

  bool isPinned(String chatId) => pinnedChatIds.contains(chatId);

  @override
  List<Object?> get props => [now, myUserId, pinnedChatIds];
}

/// Which kind of rule this is, and the key it is stored under.
///
/// The wire value is what the local store writes, so renaming one orphans
/// every folder that used it — add a new kind instead.
enum FolderRuleKind {
  chatType('chat_type'),
  unread('unread'),
  pinned('pinned'),
  noReplyFromMe('no_reply_from_me'),
  member('member');

  const FolderRuleKind(this.wire);

  final String wire;

  static FolderRuleKind? fromWire(String? value) {
    for (final kind in FolderRuleKind.values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

/// One condition a chat either meets or does not.
///
/// A folder is a set of these rather than a hand-picked list of chats, so a
/// chat joins and leaves a folder on its own as it changes.
sealed class FolderRule extends Equatable {
  const FolderRule();

  FolderRuleKind get kind;

  bool evaluate(ChatEntity chat, ChatRuleContext context);
}

/// `type ∈ {...}` — the chat is one of the listed kinds.
///
/// An empty set matches nothing: a type rule that accepts every type is the
/// same as having no rule at all, and saying so out loud beats a folder that
/// silently swallows the whole list.
final class ChatTypeRule extends FolderRule {
  const ChatTypeRule(this.types);

  final Set<ChatType> types;

  @override
  FolderRuleKind get kind => FolderRuleKind.chatType;

  @override
  bool evaluate(ChatEntity chat, ChatRuleContext context) =>
      types.contains(chat.type);

  @override
  List<Object?> get props => [types];
}

/// Whether the chat has anything unread, per `ChatDTO.unread_count`.
final class UnreadRule extends FolderRule {
  const UnreadRule({this.expected = true});

  /// `true` keeps chats with unread messages, `false` keeps the read ones.
  final bool expected;

  @override
  FolderRuleKind get kind => FolderRuleKind.unread;

  @override
  bool evaluate(ChatEntity chat, ChatRuleContext context) =>
      ((chat.unreadCount ?? 0) > 0) == expected;

  @override
  List<Object?> get props => [expected];
}

/// Whether this device pins the chat.
final class PinnedRule extends FolderRule {
  const PinnedRule({this.expected = true});

  final bool expected;

  @override
  FolderRuleKind get kind => FolderRuleKind.pinned;

  @override
  bool evaluate(ChatEntity chat, ChatRuleContext context) =>
      context.isPinned(chat.id) == expected;

  @override
  List<Object?> get props => [expected];
}

/// The ball is in my court: the last message is someone else's, and it has
/// been sitting there for at least [days].
///
/// The list row carries one message (`ChatDTO.last_message`, api-docs §5.2),
/// so "I have not replied" is read off that one message rather than off a
/// history nobody has fetched. [days] of zero means "however recent".
final class NoReplyFromMeRule extends FolderRule {
  const NoReplyFromMeRule({this.days = 0});

  static const int maxDays = 365;

  final int days;

  @override
  FolderRuleKind get kind => FolderRuleKind.noReplyFromMe;

  @override
  bool evaluate(ChatEntity chat, ChatRuleContext context) {
    final myUserId = context.myUserId;
    final last = chat.lastMessage;
    if (myUserId == null || last == null) return false;
    if (last.authorId == myUserId) return false;
    if (days <= 0) return true;

    final waited = context.now.difference(last.createdAt);
    return waited.inSeconds >= Duration(days: days).inSeconds;
  }

  @override
  List<Object?> get props => [days];
}

/// Someone in particular is in the chat.
///
/// Membership is only fully known once `GET /chats/{id}/members/` has been
/// called, which the list never does. So this matches on what a row does
/// carry: my own membership, any roster already loaded, the author of the
/// last message and the chat's creator. [label] is the name to show for
/// [userId] when no profile is at hand.
final class MemberRule extends FolderRule {
  const MemberRule({required this.userId, this.label});

  final int userId;

  final String? label;

  @override
  FolderRuleKind get kind => FolderRuleKind.member;

  @override
  bool evaluate(ChatEntity chat, ChatRuleContext context) {
    if (chat.membershipOf(userId) != null) return true;
    if (chat.lastMessage?.authorId == userId) return true;
    if (chat.createdBy == userId) return true;
    return false;
  }

  @override
  List<Object?> get props => [userId, label];
}
