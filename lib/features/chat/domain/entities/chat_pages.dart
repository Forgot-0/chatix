import 'package:equatable/equatable.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

/// Cursor-paginated envelopes for the three chat list endpoints
/// (api-docs §1.6, §6.2–§6.4).
///
/// ⚠️ These are **not** `PageResult<T>` and must not be converted into one.
/// The differences are load-bearing:
///
/// * `hasNext` is a **real field the server sends**. `PageResult` *derives*
///   `hasNext` from `page * page_size < total`; here there is no `total` and
///   no page number to derive anything from, and the server is the only
///   thing that knows whether more rows exist.
/// * The cursor is an **opaque continuation token** (a `(last_activity_at,
///   last_chat_id)` pair, a `seq`, or a `user_id`), not an offset. You cannot
///   jump to "page 3", cannot re-request a page you already consumed, and
///   must feed the previous response's cursor into the next request verbatim.
/// * Cursor pagination is stable under concurrent inserts — which is exactly
///   why chats use it: a new message arriving mid-scroll shifts no rows,
///   whereas an offset-based page 2 would skip or duplicate them.
///
/// Each wrapper names its cursor fields after the request parameter they feed
/// (documented per field) so the round-trip can't be misread at the call site.

/// `ListChats` — response of `GET /chats/` (api-docs §6.2).
class ChatsPage extends Equatable {
  final List<ChatEntity> chats;

  /// Sent by the server — never computed from `chats.length`.
  final bool hasNext;

  /// Pass back as `last_activity_at`. ISO 8601 string rather than
  /// `DateTime`: it is an opaque cursor to be echoed byte-for-byte, and
  /// round-tripping it through `DateTime` risks losing sub-second precision
  /// or shifting the timezone suffix, which would silently skip or repeat
  /// rows at the page boundary.
  final String? nextDate;

  /// Pass back as `last_chat_id`. Both cursor parts are needed together —
  /// `last_activity_at` alone is not unique across chats.
  final String? nextChatId;

  const ChatsPage({
    required this.chats,
    required this.hasNext,
    required this.nextDate,
    required this.nextChatId,
  });

  /// True when the server says there is more *and* actually gave us a cursor
  /// to get it with. Guards against an endless "load more" loop if a
  /// `has_next: true` response ever arrives with null cursors.
  bool get canLoadMore => hasNext && (nextChatId != null || nextDate != null);

  @override
  List<Object?> get props => [chats, hasNext, nextDate, nextChatId];
}

/// `MessagesDTO` — response of `GET /chats/{id}/messages/` and
/// `GET /chats/{id}/messages/context/` (api-docs §6.4).
class MessagesPage extends Equatable {
  /// Newest-first, as returned by the backend. The chat screen renders a
  /// reversed list, so this order is kept as-is rather than sorted here.
  final List<MessageEntity> messages;

  /// Pass back as `cursor_message_seq`. An `int` (a message `seq`), not a
  /// date — unlike [ChatsPage]'s cursor.
  final int? nextCursor;

  /// Sent by the server.
  final bool hasNext;

  const MessagesPage({
    required this.messages,
    required this.nextCursor,
    required this.hasNext,
  });

  bool get canLoadMore => hasNext && nextCursor != null;

  @override
  List<Object?> get props => [messages, nextCursor, hasNext];
}

/// `ListMembers` — response of `GET /chats/{id}/members/` (api-docs §6.3).
class MembersPage extends Equatable {
  final List<ChatMemberEntity> members;

  /// Sent by the server.
  final bool hasNext;

  /// Pass back as `cursor_user_id`.
  final int? nextUserId;

  /// Only non-empty when the request passed `include_presence=true`
  /// (api-docs §6.3). It is a **parallel list keyed by `user_id`**, not a
  /// field on each member — join it via [presenceOf] rather than assuming
  /// index alignment with [members].
  final List<MemberPresenceEntity> presence;

  const MembersPage({
    required this.members,
    required this.hasNext,
    required this.nextUserId,
    this.presence = const [],
  });

  bool get canLoadMore => hasNext && nextUserId != null;

  /// `null` when presence wasn't requested or this member simply wasn't
  /// included — which must render as "unknown", not as "offline".
  bool? presenceOf(int userId) {
    for (final entry in presence) {
      if (entry.userId == userId) return entry.isOnline;
    }
    return null;
  }

  @override
  List<Object?> get props => [members, hasNext, nextUserId, presence];
}
