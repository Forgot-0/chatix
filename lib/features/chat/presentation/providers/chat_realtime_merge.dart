import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';

/// The **pure** merge rules for folding WebSocket events into local state
/// (api-docs §7.4/§7.5, §10.5).
///
/// Everything here is a plain function over immutable values: no Riverpod, no
/// `ref`, no HTTP, no sockets, and no `WSEvent` types. Controllers unwrap an
/// event first — decoding `payload.message` with `MessageModel.fromJson` where
/// there is one (`new_message`, `message_edited`), and passing the
/// `payload.event` delta's fields through where there isn't — then hand plain
/// values in here. That keeps this file testable with plain entities and keeps
/// the "which WS event means what" knowledge in one place (the controllers),
/// rather than split across two layers.
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
  /// already the full decoded `MessageDTO` from the event (api-docs §7.4),
  /// and this only reads its [MessageEntity.seq] to advance
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

  /// Applies a `chat_updated` delta to a locally-held row (§7.4).
  ///
  /// The event's `payload.event` is exactly the set of settings that changed —
  /// it mirrors `UpdateChatRequest` (§6.2) plus the reaction settings of
  /// §6.7.5 — so the parameters here are that delta, one for one, and nothing
  /// else about the chat is touched.
  ///
  /// ⚠️ **`null` means "not part of this change", never "cleared".**
  /// `PATCH /chats/{chat_id}/` is a true partial update with no way to null a
  /// field back out (§6.2), so a `null` in the delta can only mean the field
  /// was left alone — hence `??` throughout. This is the opposite of the rule
  /// that applied when this event carried a whole `ChatDTO` snapshot, where a
  /// `null` name had to be assigned to avoid a cleared name sticking on screen.
  /// With a delta the ambiguity is gone.
  ///
  /// Nothing personalised to the viewer ([ChatEntity.unreadCount],
  /// [ChatEntity.me], [ChatEntity.lastRead], [ChatEntity.lastMessage],
  /// [ChatEntity.members]) can be affected, because the delta simply does not
  /// contain those fields — the event is a broadcast and they are per-viewer.
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

  /// Applies a `reaction_update` snapshot to the message it names (§6.7.6).
  ///
  /// [groups] is the **complete current set** of reaction groups for
  /// [messageId], so this replaces rather than accumulates — but it goes
  /// through [MessageReactionsEntity.applySnapshot] rather than assigning
  /// directly, for two reasons spelled out there: the broadcast snapshot's
  /// `reacted_by_me` is always `false` and must not clobber the local flags,
  /// and a coalesced/at-least-once frame can arrive out of order and is
  /// rejected per group by `version`.
  ///
  /// [actorId] and [myUserId] let the one case that carry-over gets wrong —
  /// our own reaction made on another device — be resolved from the snapshot.
  ///
  /// A no-op when [messageId] isn't loaded: reactions on a message scrolled
  /// out of the window will be correct when it is fetched, since
  /// `MessageDTO.reactions` carries them inline (§6.4).
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

  /// Replaces one message's reaction groups outright — the optimistic path.
  ///
  /// Separate from [applyReactionSnapshot] because the two have opposite
  /// trust models: there the server's snapshot is authoritative about counts
  /// and the local state is authoritative about "mine"; here the caller has
  /// just computed both locally (`addMine`/`removeMine`/`replaceMine`) and
  /// wants them stored verbatim, including the rollback case.
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

  /// Applies a member-count delta from a membership event (§7.4).
  ///
  /// Used for all four — `member_joined` (+1), `member_left`, `member_kick`
  /// and `member_banned` with `ban: true` (−1) — because each of those carries
  /// the affected `user_id`/`target_user_id` in its delta, so the controller
  /// can decide locally whether it was *us* (drop the row entirely) or someone
  /// else (adjust the count) without a refetch.
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
            // Lower bound only. The old upper bound of `memberCount + 1`
            // silently swallowed any delta larger than one; the count can only
            // ever move by ±1 per event, so the meaningful guard is the floor.
            memberCount: (c.memberCount + delta) < 0 ? 0 : c.memberCount + delta,
          )
        else
          c,
    ];
  }
}
