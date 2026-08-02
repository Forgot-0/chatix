import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/core/websocket/ws_event.dart';

/// The **pure** merge rules for folding WebSocket events into local state
/// (api-docs §7.4/§7.5, §10.5).
///
/// Everything here is a plain function over immutable values: no Riverpod, no
/// `ref`, no HTTP, no sockets. That is deliberate and is the whole reason this
/// file exists separately from the controllers.
///
/// ## Why the rules are not inlined into the controllers
///
/// The protocol's central hazard is that `new_message`, `message_edited` and
/// `message_deleted` are **notifications, not data** — the payload is
/// `{message_id, seq, …}` with no content whatsoever (§7.4). Getting the
/// merge wrong therefore does not throw; it produces duplicated bubbles,
/// messages that appear out of order, or a chat that silently stops updating.
/// Those are exactly the bugs that are invisible in a widget test and obvious
/// to a user.
///
/// Keeping the decisions as pure functions means they can be tested
/// exhaustively — every ordering, every duplicate, every own-message case —
/// without a server, a timer or a socket. The controllers below are left with
/// only I/O and state assignment.
///
/// ## Ordering invariant
///
/// `GET /chats/{id}/messages/` returns **newest first** and the chat screen
/// renders a `reverse: true` list, so every list here is kept in
/// **descending `seq`** order. `seq` — not `createdAt` — is the ordering key:
/// it is the per-chat monotonic counter the protocol itself uses for cursors
/// (§6.4), and two messages can share a timestamp but never a `seq`.
abstract final class ChatRealtimeMerge {
  // ─────────────────────────── Message list merges ───────────────────────────

  /// Inserts [message] into [messages] (descending `seq`), replacing any
  /// existing entry with the same id.
  ///
  /// This single function covers insert, update and idempotent re-delivery,
  /// because all three are the same operation on a keyed, sorted list:
  ///
  /// * **De-duplication by `id`** is what makes the optimistic-send path safe.
  ///   A message we posted over REST is already on screen; if it is also
  ///   fetched in response to a `ws.history` replay or a racing `new_message`,
  ///   this replaces it in place instead of appending a second bubble
  ///   (§10.5 (a)).
  /// * **Position by `seq`** rather than "prepend to the front". A `new_message`
  ///   is *usually* the newest, but not always: `ws.history` replays a gap
  ///   oldest-to-newest after a reconnect (§7.4), and a slow fetch of an
  ///   earlier message can land after a later one. Prepending blindly would
  ///   render the conversation out of order.
  ///
  /// Uses linear insertion, not a re-sort: the list is already ordered, and a
  /// newly arrived message is almost always at index 0, so this exits after one
  /// comparison in the common case.
  static List<MessageEntity> upsertMessage(
    List<MessageEntity> messages,
    MessageEntity message,
  ) {
    final result = <MessageEntity>[];
    var inserted = false;

    for (final existing in messages) {
      // Drop the previous copy of this message wherever it sat. Its `seq` is
      // immutable server-side, but an edit could arrive with a fresher body,
      // and dropping-then-inserting keeps one code path for both.
      if (existing.id == message.id) continue;

      if (!inserted && message.seq > existing.seq) {
        result.add(message);
        inserted = true;
      }
      result.add(existing);
    }

    // Oldest message in the list (or the list was empty).
    if (!inserted) result.add(message);

    return result;
  }

  /// Applies a `message_deleted` event (§7.4).
  ///
  /// Two behaviours, chosen by [asTombstone]:
  ///
  /// * `false` (default) — remove the row outright.
  /// * `true` — keep it in place with its content and attachments cleared, so
  ///   the bubble can read "message deleted".
  ///
  /// A tombstone is the better default for a *group* conversation, where a
  /// vanishing row silently rewrites what the remaining messages appear to be
  /// replying to. It is offered as a flag rather than hard-coded because the
  /// protocol supports either and the choice is a product decision.
  ///
  /// Either way this is a **local-only** update: the message is already gone
  /// server-side, so there is nothing to fetch and no way to recover its body.
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

  /// Whether a `new_message` event needs a follow-up
  /// `GET /chats/{chat_id}/messages/{message_id}/`.
  ///
  /// This is the §7.5 step-3 decision, and the two `false` cases are the ones
  /// that matter:
  ///
  /// * **Our own message** (`event.senderId == myUserId`). It was already
  ///   inserted from the `POST /messages/` response, so a fetch would spend a
  ///   round-trip to learn something we already know — and, if the merge were
  ///   keyed on anything looser than `id`, would duplicate the bubble
  ///   (§10.5 (a)). Note this is checked *before* the id lookup: the event can
  ///   arrive before our own POST has returned, so the message may legitimately
  ///   not be in [messages] yet and re-fetching it would race the optimistic
  ///   insert.
  /// * **Already present.** A re-delivery, or a `ws.history` replay covering a
  ///   message we have.
  ///
  /// [myUserId] may be `null` (auth still resolving); the own-message shortcut
  /// is then skipped and the message is fetched, which is wasteful but never
  /// wrong.
  static bool shouldFetchMessage(
    NewMessage event,
    List<MessageEntity> messages, {
    required int? myUserId,
  }) {
    if (myUserId != null && event.senderId == myUserId) return false;
    return !messages.any((m) => m.id == event.messageId);
  }

  /// The highest `seq` we hold for a chat — the value to hand to
  /// `subscribe(chatId, lastSeq:)` so the server replays only the gap (§7.3).
  ///
  /// Reads the whole list rather than trusting `messages.first`: the ordering
  /// invariant makes index 0 the newest, but a wrong cursor here silently skips
  /// messages forever, so this does not depend on the invariant holding.
  ///
  /// `null` for an empty list — meaning "no cursor", which correctly asks for
  /// no history rather than for everything since `seq` 0.
  static int? highestSeq(List<MessageEntity> messages) {
    int? highest;
    for (final m in messages) {
      if (highest == null || m.seq > highest) highest = m.seq;
    }
    return highest;
  }

  // ──────────────────────────── Chat list merges ─────────────────────────────

  /// Applies a `new_message` to a chat **row** in the list — the §7.5 path for
  /// a chat that is *not* currently on screen.
  ///
  /// Deliberately does **not** fetch the message. The list shows a badge and a
  /// timestamp, neither of which needs the body; paying for a request per
  /// incoming message across every chat the user belongs to would turn a busy
  /// group into a request storm for content that is never rendered. The body is
  /// fetched if and when the user opens that chat.
  ///
  /// [isOpen] suppresses the badge for the chat the user is looking at — its
  /// controller marks it read on arrival, so incrementing here would show an
  /// unread count for messages being read right now.
  ///
  /// [isOwn] suppresses it for our own sends, which are never unread to us.
  ///
  /// ⚠️ [ChatEntity.unreadCount] is nullable and `null` means *"this endpoint
  /// didn't send it"*, not zero (see [ChatEntity]). A `null` is therefore left
  /// as `null` rather than being promoted to `1`: inventing a count from
  /// unknown would show a badge of "1" on a chat with 400 unread messages.
  static ChatEntity applyNewMessageToRow(
    ChatEntity chat,
    NewMessage event, {
    required bool isOpen,
    required bool isOwn,
  }) {
    final shouldBump = !isOpen && !isOwn;
    final current = chat.unreadCount;

    return chat.copyWith(
      // `seq_counter` tracks the newest message's seq (§6.2). Guarded with a
      // max so a re-delivered older event cannot rewind it.
      seqCounter: event.seq > chat.seqCounter ? event.seq : chat.seqCounter,
      // Drives the list's sort order and its "last active" label. The event's
      // `ts` is nullable, so fall back to now — the message demonstrably just
      // arrived.
      lastActivityAt: event.ts ?? DateTime.now(),
      unreadCount: shouldBump && current != null ? current + 1 : current,
    );
  }

  /// Applies a `messages_read` event (§7.4).
  ///
  /// ⚠️ **Only when the reader is us.** `messages_read` is broadcast to the
  /// whole chat subscription, so it also reports *other* members reading their
  /// own copies — clearing our badge because someone else caught up would be
  /// straightforwardly wrong. Callers pass [myUserId] and this returns [chat]
  /// untouched when it doesn't match.
  ///
  /// This is what keeps the badge honest across devices: reading a chat on a
  /// phone clears it on a tablet, with no refetch.
  ///
  /// The count is *not* recomputed from `seq` arithmetic (e.g.
  /// `seqCounter - seq`), because `seqCounter` counts every message including
  /// our own, and system messages may not count as unread server-side. Read up
  /// to the newest known message means zero unread; anything earlier is a
  /// partial read whose exact remainder only the server knows, so the count is
  /// left alone rather than guessed at.
  static ChatEntity applyMessagesRead(
    ChatEntity chat,
    MessagesRead event, {
    required int? myUserId,
  }) {
    if (myUserId == null || event.readerId != myUserId) return chat;

    final caughtUp = event.seq >= chat.seqCounter;

    return chat.copyWith(
      unreadCount: caughtUp ? 0 : chat.unreadCount,
      lastRead: ReadDetailEntity(
        lastReadMessageSeq: event.seq,
        lastReadAt: event.ts ?? DateTime.now(),
      ),
    );
  }

  /// Applies a `chat_updated` event (§7.4).
  ///
  /// The one domain event that carries its full new state, so it can be
  /// applied with no follow-up request at all.
  ///
  /// ⚠️ `name` and `description` are `string | null` on the wire and null is a
  /// *real value* — clearing a group's description sends `null`. They are
  /// therefore assigned directly rather than through `copyWith`'s
  /// "null means unchanged" parameters, which would make a cleared description
  /// stick around on screen forever.
  static ChatEntity applyChatUpdated(ChatEntity chat, ChatUpdated event) {
    return ChatEntity(
      id: chat.id,
      seqCounter: chat.seqCounter,
      lastActivityAt: chat.lastActivityAt,
      type: chat.type,
      name: event.name,
      description: event.description,
      avatarS3Key: chat.avatarS3Key,
      isPublic: event.isPublic,
      adminOnly: event.adminOnly,
      slowModeSeconds: event.slowModeSeconds,
      permissions: event.permissions,
      createdBy: chat.createdBy,
      memberCount: chat.memberCount,
      unreadCount: chat.unreadCount,
      me: chat.me,
      lastRead: chat.lastRead,
      members: chat.members,
    );
  }

  /// Re-orders [chats] by `last_activity_at`, newest first — the order
  /// `GET /chats/` itself returns (§6.2).
  ///
  /// Needed because [applyNewMessageToRow] changes a row's activity timestamp
  /// without moving it: a message arriving in the tenth chat must float it to
  /// the top, which is the visible half of "the list updates live".
  ///
  /// Rows with a `null` timestamp (a chat that has never had a message) sort
  /// last, matching where the server puts them.
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

  /// Removes a chat from the list — `chat_deleted`, `member_kick`/`member_left`
  /// naming us, or a `member_banned` ban naming us.
  ///
  /// All four mean the same thing to the list: the row must go, because the
  /// next `GET /chats/` won't include it and tapping it would 403/404.
  static List<ChatEntity> removeChat(List<ChatEntity> chats, String chatId) {
    return chats.where((c) => c.id != chatId).toList();
  }

  /// Applies a member-count delta from `member_joined` / `member_left` /
  /// `member_kick` (§7.4).
  ///
  /// Clamped at zero: a duplicated leave event must not render "-1 members".
  static List<ChatEntity> adjustMemberCount(
    List<ChatEntity> chats,
    String chatId,
    int delta,
  ) {
    return [
      for (final c in chats)
        if (c.id == chatId)
          c.copyWith(
            memberCount: (c.memberCount + delta).clamp(0, c.memberCount + 1),
          )
        else
          c,
    ];
  }
}
