import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

/// The **pure** merge rules for folding WebSocket events into local state
/// (api-docs §7.4/§7.5, §10.5).
///
/// Everything here is a plain function over immutable values: no Riverpod, no
/// `ref`, no HTTP, no sockets, and — since the §7.4 payload revision — no
/// `WSEvent` types either. Controllers decode the event's raw `chat`/`message`
/// JSON (`WSChatMessageEvent`) into `ChatEntity`/`MessageEntity` first, using
/// the same `ChatModel.fromJson`/`MessageModel.fromJson` REST already relies
/// on, and hand the decoded entities in here. That keeps this file testable
/// with plain entities and keeps the "which WS event means what" knowledge in
/// one place (the controllers), rather than split across two layers.
///
/// ## Why the rules are not inlined into the controllers
///
/// Getting a merge wrong does not throw; it produces duplicated bubbles,
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
  /// Deliberately does **not** need to fetch anything itself: [message] is
  /// already the full decoded `MessageDTO` from the event (api-docs §7.4,
  /// revised), and this only reads its [MessageEntity.seq] to advance
  /// [ChatEntity.seqCounter]. The list still never renders the body — a
  /// preview would need `last_message` refreshed too, which is a product
  /// decision left to the caller, not forced here.
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
    MessageEntity message, {
    required DateTime? ts,
    required bool isOpen,
    required bool isOwn,
  }) {
    final shouldBump = !isOpen && !isOwn;
    final current = chat.unreadCount;

    return chat.copyWith(
      // `seq_counter` tracks the newest message's seq (§6.2). Guarded with a
      // max so a re-delivered older event cannot rewind it.
      seqCounter: message.seq > chat.seqCounter ? message.seq : chat.seqCounter,
      // Drives the list's sort order and its "last active" label. The
      // envelope's `ts` is nullable, so fall back to now — the message
      // demonstrably just arrived.
      lastActivityAt: ts ?? DateTime.now(),
      unreadCount: shouldBump && current != null ? current + 1 : current,
    );
  }

  /// Applies a `chat_updated` event (§7.4).
  ///
  /// [updated] is the full new `ChatDTO` decoded from the event's `chat` field
  /// — [chat] is the locally-held row before the update.
  ///
  /// Only the **settings** fields (`name`, `description`, `avatar_s3_key`,
  /// `is_public`, `admin_only`, `slow_mode_seconds`, `permissions`) are taken
  /// from [updated]; everything personalised to the viewer
  /// ([ChatEntity.unreadCount], [ChatEntity.me], [ChatEntity.lastRead],
  /// [ChatEntity.lastMessage], [ChatEntity.members]) is kept from [chat]
  /// instead. This is deliberate, not an oversight: `chat_updated`'s embedded
  /// `ChatDTO` is built once by `ChatDeliveryRouter` and fanned out to every
  /// recipient of the broadcast (api-docs §7.4, revised), with no documented
  /// guarantee that fields like `me`/`unread_count` are recomputed per
  /// recipient. Trusting them here risks silently overwriting a correct,
  /// personal read cursor with a stranger's (or a default/null) one.
  ///
  /// ⚠️ `name`/`description` being `null` on [updated] is still ambiguous
  /// between "cleared" and "this snapshot just doesn't carry it" — assigned
  /// directly (not through `copyWith`'s "null means unchanged" parameters)
  /// because the alternative would make a genuinely cleared description stick
  /// around on screen forever.
  static ChatEntity applyChatUpdated(ChatEntity chat, ChatEntity updated) {
    return ChatEntity(
      id: chat.id,
      seqCounter: chat.seqCounter,
      lastActivityAt: chat.lastActivityAt,
      type: chat.type,
      name: updated.name,
      description: updated.description,
      avatarS3Key: updated.avatarS3Key,
      isPublic: updated.isPublic,
      adminOnly: updated.adminOnly,
      slowModeSeconds: updated.slowModeSeconds,
      permissions: updated.permissions,
      createdBy: chat.createdBy,
      memberCount: chat.memberCount,
      unreadCount: chat.unreadCount,
      me: chat.me,
      lastRead: chat.lastRead,
      lastMessage: chat.lastMessage,
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

  /// Removes a chat from the list — `chat_deleted`, or a refetch after
  /// `member_kick`/`member_left`/`member_banned` coming back access-denied
  /// (i.e. it turned out to be *us* who left/was removed; see
  /// `ChatListController`).
  ///
  /// Either way this means the same thing to the list: the row must go,
  /// because the next `GET /chats/` won't include it and tapping it would
  /// 403/404.
  static List<ChatEntity> removeChat(List<ChatEntity> chats, String chatId) {
    return chats.where((c) => c.id != chatId).toList();
  }

  /// Applies a member-count delta from `member_joined` (§7.4).
  ///
  /// ⚠️ No longer used for `member_left`/`member_kick`/`member_banned`: those
  /// three lost their `user_id`/`target_user_id` fields in the §7.4 payload
  /// revision, so a consumer can no longer tell locally whether the departing
  /// member was *us* (drop the whole row) or someone else (just decrement).
  /// `ChatListController`/`ChatDetailController` now re-fetch the chat for all
  /// three instead — see `WSChatMessageEvent`'s class doc. `member_joined`
  /// keeps the cheap local increment because it never needed that identity: a
  /// join always means "count + 1" regardless of who joined.
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
