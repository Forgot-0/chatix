import 'package:equatable/equatable.dart';

/// Message reactions (api-docs §6.7).
///
/// ## Telegram-like: a *set* per user, not a single choice
///
/// A user may hold **several** different emoji on one message — up to
/// [ReactionLimits.maxPerUserPerMessage] (§6.7.2). Consequences this file is
/// shaped around:
///
/// * `PUT .../reactions/{emoji}/` **adds** to the user's set; it does not
///   replace it. Re-sending an emoji already held is a server-side no-op.
/// * `PUT .../reactions/` with `{ "reactions": [...] }` replaces the whole
///   set at once (`messages.sendReaction` semantics) — an empty list clears
///   it. That is [replaceMine].
/// * Several [ReactionGroupEntity]s may carry `reactedByMe == true` at the
///   same time; ask [MessageReactionsEntity.myEmojis] (plural), never a
///   single-valued accessor.
///
/// ## Where a summary comes from
///
/// Unlike the previous revision, `MessageDTO` **carries its reactions inline**
/// (`MessageDTO.reactions`, §6.4/§6.7.3) in list, detail, context and
/// `ws.history` responses. So a message arrives with its chips already
/// attached and no companion `GET .../reactions/` is needed to render them.
///
/// They are then kept current by the `reaction_update` WS event, which ships a
/// **full snapshot** of the groups (`payload.reaction.groups`, §6.7.6) — again
/// no re-fetch. The standalone `GET .../reactions/` endpoint is only for
/// paginating *who* reacted with a given emoji.
///
/// ⚠️ The snapshot in that event is **not personalised**: `reacted_by_me` is
/// always `false` in it (§6.7.6). Merging one must therefore preserve the
/// local "mine" flags — see [applySnapshot], which is the only supported way
/// to fold the event in.

/// Server-side reaction limits (api-docs §6.7.4).
///
/// Mirrored client-side so the UI can refuse an over-limit tap instead of
/// spending one of the 10/sec rate-limit slots on a request that will come
/// back `400 TOO_MANY_REACTIONS`. The backend stays authoritative.
abstract final class ReactionLimits {
  /// `MAX_REACTIONS_PER_USER_PER_MESSAGE` — how many different emoji one user
  /// may hold on a single message (§6.7.4).
  static const int maxPerUserPerMessage = 3;

  /// `MAX_DISTINCT_REACTIONS_PER_MESSAGE` — how many different emoji may exist
  /// on a message across all users (§6.7.4).
  static const int maxDistinctPerMessage = 20;

  /// `MAX_REACTION_LENGTH` — an emoji is a string, and a composed one (skin
  /// tone, ZWJ sequence) is several code units long (§6.7.4).
  static const int maxEmojiLength = 32;

  /// `REACTION_RECENT_USERS_LIMIT` — how many entries
  /// [ReactionGroupEntity.recentUserIds] can hold (§6.7.3).
  static const int recentUsersLimit = 3;
}

/// `reaction.action` of the `reaction_update` WS event (api-docs §6.7.6) —
/// what the actor did to produce the snapshot that accompanies it.
///
/// Purely informational: the event always carries the **full** current set of
/// groups, so no consumer has to reconstruct anything from the verb. It is
/// modelled because it is the only thing distinguishing an actor's single tap
/// from a whole-set replacement in logs and in "N reacted" toasts.
enum ReactionAction {
  add,
  remove,
  replace,
  update;

  static ReactionAction fromWire(String? value) {
    return ReactionAction.values.firstWhere(
      (a) => a.name == value,
      // An unknown verb still comes with a valid snapshot, so degrading to the
      // neutral "update" keeps the event usable rather than dropping it.
      orElse: () => ReactionAction.update,
    );
  }
}

/// `ReactionGroupDTO` (api-docs §6.7.3) — one emoji "chip" under a message,
/// aggregated across everyone who used it.
class ReactionGroupEntity extends Equatable {
  /// The emoji itself, 1..[ReactionLimits.maxEmojiLength] characters.
  ///
  /// Kept as the raw, unescaped string: it is a display value here, and the
  /// percent-encoding it needs as a path parameter is applied at the data
  /// source boundary rather than baked into the entity (which would then
  /// render the escaped form).
  final String emoji;

  /// How many people reacted with [emoji] — always **absolute**, never a
  /// delta. The WS snapshot is absolute too (§6.7.6).
  final int count;

  /// Monotonic per-group version (api-docs §6.7.3).
  ///
  /// The reason it is on the wire at all: reaction fan-out is coalesced
  /// (§6.7.6) and delivered at-least-once (§7.4), so two snapshots for the
  /// same message can arrive out of order. Comparing versions makes folding
  /// one in idempotent — see [MessageReactionsEntity.applySnapshot], which
  /// drops a group whose version is older than the one already held.
  final int version;

  /// Whether the current user is among those who reacted with [emoji].
  ///
  /// ⚠️ Several groups may have this set at once (see the library doc). It is
  /// also **always `false`** inside a `reaction_update` snapshot (§6.7.6),
  /// which is why merging goes through [MessageReactionsEntity.applySnapshot]
  /// instead of a plain assignment.
  final bool reactedByMe;

  /// Up to [ReactionLimits.recentUsersLimit] most recent reactor ids, for the
  /// stacked avatars on the chip (§6.7.3). Not a complete list — the full one
  /// is paginated through `GET .../reactions/?emoji=`.
  final List<int> recentUserIds;

  const ReactionGroupEntity({
    required this.emoji,
    required this.count,
    this.version = 0,
    this.reactedByMe = false,
    this.recentUserIds = const [],
  });

  ReactionGroupEntity copyWith({
    int? count,
    int? version,
    bool? reactedByMe,
    List<int>? recentUserIds,
  }) {
    return ReactionGroupEntity(
      emoji: emoji,
      count: count ?? this.count,
      version: version ?? this.version,
      reactedByMe: reactedByMe ?? this.reactedByMe,
      recentUserIds: recentUserIds ?? this.recentUserIds,
    );
  }

  @override
  List<Object?> get props => [
    emoji,
    count,
    version,
    reactedByMe,
    recentUserIds,
  ];
}

/// `MessageReactionsDTO` (api-docs §6.7.3) — the response of
/// `GET .../reactions/`, which serves **two** purposes:
///
/// 1. **Without `?emoji=`** — the chip summary for a message. [groups] is
///    populated, [users] is empty and [hasNext] is `false`.
/// 2. **With `?emoji=👍`** — additionally a paginated page of *who* reacted
///    with it, for the long-press sheet. [groups] is still sent in full.
///
/// Both shapes are one DTO server-side, so they are one entity here; [emoji]
/// echoes the query parameter and is the discriminator between them.
///
/// This same type also models the chips attached inline to a message
/// (`MessageDTO.reactions`) — see [MessageReactionsEntity.fromGroups], which
/// is how `MessageEntity.reactions` is lifted into one.
class MessageReactionsEntity extends Equatable {
  /// ⚠️ A plain `string` on the wire, not a UUID-typed field (§6.7.3) —
  /// matching [MessageEntity.id], which is also a string.
  final String messageId;

  /// Every emoji on this message with its absolute count, sorted by the
  /// backend `count DESC, emoji ASC` (§6.7.3). Complete in both modes, and
  /// the only thing the chip row needs.
  final List<ReactionGroupEntity> groups;

  /// Echo of the `?emoji=` query parameter; `null` in summary-only mode.
  final String? emoji;

  /// Who reacted with [emoji] — **non-empty only when [emoji] is set**.
  ///
  /// ⚠️ Bare `user_id`s (§6.7.3), not objects: there is no name or avatar in
  /// this response. The sheet resolves them against the chat roster
  /// (`ChatDetailDTO.members` / `MessageDTO.profile`), and falls back to
  /// `User #id`.
  final List<int> users;

  /// Whether another page of [users] exists.
  final bool hasNext;

  /// Cursor for the next page — pass back as `cursor_user_id`. `null` when
  /// [hasNext] is false.
  final int? nextUserId;

  const MessageReactionsEntity({
    required this.messageId,
    this.groups = const [],
    this.emoji,
    this.users = const [],
    this.hasNext = false,
    this.nextUserId,
  });

  /// An empty summary — what a message with no reactions looks like. Used as
  /// the default so the UI never has to distinguish "no reactions" from "not
  /// loaded yet" when rendering the (absent) chip row.
  factory MessageReactionsEntity.empty(String messageId) =>
      MessageReactionsEntity(messageId: messageId);

  /// Lifts the groups carried inline on a `MessageDTO` (§6.4) into a summary.
  ///
  /// The inline field is the *primary* source of chips since §6.7.3 — this is
  /// what makes the old "fetch a summary per visible message" pass
  /// unnecessary.
  factory MessageReactionsEntity.fromGroups(
    String messageId,
    List<ReactionGroupEntity> groups,
  ) => MessageReactionsEntity(messageId: messageId, groups: groups);

  bool get isEmpty => groups.isEmpty;

  /// Every emoji the current user holds on this message — 0..
  /// [ReactionLimits.maxPerUserPerMessage] of them (§6.7.2).
  ///
  /// Plural by design: the single-choice model this replaced could not express
  /// a user holding 👍 and 🔥 at once, which the backend now allows.
  List<String> get myEmojis => [
    for (final group in groups)
      if (group.reactedByMe) group.emoji,
  ];

  bool isMine(String emoji) => myEmojis.contains(emoji);

  /// Whether the user may add *one more* distinct emoji (§6.7.4). False both
  /// when their own set is full and when the message itself has hit
  /// [ReactionLimits.maxDistinctPerMessage].
  bool get canAddMore =>
      myEmojis.length < ReactionLimits.maxPerUserPerMessage &&
      groups.length < ReactionLimits.maxDistinctPerMessage;

  MessageReactionsEntity copyWith({
    List<ReactionGroupEntity>? groups,
    String? emoji,
    List<int>? users,
    bool? hasNext,
    int? nextUserId,
    bool clearNextUserId = false,
  }) {
    return MessageReactionsEntity(
      messageId: messageId,
      groups: groups ?? this.groups,
      emoji: emoji ?? this.emoji,
      users: users ?? this.users,
      hasNext: hasNext ?? this.hasNext,
      nextUserId: clearNextUserId ? null : (nextUserId ?? this.nextUserId),
    );
  }

  /// Folds a `reaction_update` snapshot (§6.7.6) into the local summary.
  ///
  /// The event carries the **complete current set** of groups, so this is a
  /// replacement rather than a patch — but two things stop it being a plain
  /// assignment:
  ///
  /// * **`reacted_by_me` is always `false` in the event** (§6.7.6): the
  ///   snapshot is broadcast, not rendered per viewer. Assigning it verbatim
  ///   would clear the user's own highlighted chips on every reaction anyone
  ///   else makes. The local flags are carried over instead, keyed by emoji —
  ///   they are ours to know, and [addMine]/[removeMine] already maintain them
  ///   optimistically.
  /// * **Frames can arrive out of order** (coalescing + at-least-once, §7.4).
  ///   A group whose [ReactionGroupEntity.version] is *older* than the one
  ///   already held is stale and is dropped, keeping the merge idempotent.
  ///
  /// [actorId] and [myUserId] together handle the one case the flag carry-over
  /// gets wrong: our *own* action, arriving from another device. There the
  /// snapshot's membership is authoritative — we may have reacted or un-reacted
  /// elsewhere — so the flags are taken from [ReactionGroupEntity.recentUserIds]
  /// where they can be, and otherwise left as the local state has them.
  MessageReactionsEntity applySnapshot(
    List<ReactionGroupEntity> snapshot, {
    int? actorId,
    int? myUserId,
  }) {
    final mine = {for (final group in groups) group.emoji: group.reactedByMe};
    final versions = {for (final group in groups) group.emoji: group.version};

    // Our own change made on another device: the local "mine" flags are the
    // stale ones, so prefer what the snapshot can tell us about ourselves.
    final selfId = (actorId != null && actorId == myUserId) ? myUserId : null;

    final next = <ReactionGroupEntity>[];
    for (final group in snapshot) {
      final known = versions[group.emoji];
      if (known != null && group.version < known) {
        // Out-of-order frame for this group — keep what we already have.
        final current = groups.firstWhere((g) => g.emoji == group.emoji);
        next.add(current);
        continue;
      }

      final local = mine[group.emoji] ?? false;
      // `recentUserIds` is only the last few reactors, so finding ourselves
      // there proves we reacted but *not* finding ourselves proves nothing —
      // hence the fallback to the local flag rather than a plain `contains`.
      final reactedByMe =
          selfId != null && group.recentUserIds.contains(selfId)
          ? true
          : local;

      next.add(group.copyWith(reactedByMe: reactedByMe));
    }

    return copyWith(groups: next);
  }

  /// Optimistic local add of one emoji to the user's set, applied the moment
  /// `PUT .../reactions/{emoji}/` is issued rather than when the WS event
  /// returns (§6.7.2 recommends exactly this).
  ///
  /// A no-op when the emoji is already held — matching the server, where a
  /// repeat `PUT` is a no-op that still answers 204 — and when adding it would
  /// break [canAddMore].
  MessageReactionsEntity addMine(String emoji, {int? myUserId}) {
    if (isMine(emoji)) return this;
    if (!canAddMore && !groups.any((g) => g.emoji == emoji)) return this;
    if (myEmojis.length >= ReactionLimits.maxPerUserPerMessage) return this;

    final next = [...groups];
    final index = next.indexWhere((g) => g.emoji == emoji);

    if (index >= 0) {
      final group = next[index];
      next[index] = group.copyWith(
        count: group.count + 1,
        reactedByMe: true,
        recentUserIds: myUserId == null
            ? group.recentUserIds
            : [
                myUserId,
                ...group.recentUserIds.where((id) => id != myUserId),
              ].take(ReactionLimits.recentUsersLimit).toList(),
      );
    } else {
      next.add(
        ReactionGroupEntity(
          emoji: emoji,
          count: 1,
          reactedByMe: true,
          recentUserIds: myUserId == null ? const [] : [myUserId],
        ),
      );
    }

    return copyWith(groups: next);
  }

  /// Optimistic local removal of one of the user's emoji, for
  /// `DELETE .../reactions/{emoji}/`. A no-op when it isn't held — again
  /// matching the server's 204 no-op.
  MessageReactionsEntity removeMine(String emoji, {int? myUserId}) {
    if (!isMine(emoji)) return this;

    final next = <ReactionGroupEntity>[];
    for (final group in groups) {
      if (group.emoji != emoji) {
        next.add(group);
        continue;
      }
      final count = group.count - 1;
      // The last holder left: the chip disappears rather than rendering a 0.
      if (count <= 0) continue;
      next.add(
        group.copyWith(
          count: count,
          reactedByMe: false,
          recentUserIds: myUserId == null
              ? group.recentUserIds
              : group.recentUserIds.where((id) => id != myUserId).toList(),
        ),
      );
    }

    return copyWith(groups: next);
  }

  /// Optimistic "tap a chip" toggle: remove [emoji] if the user holds it, add
  /// it otherwise. The composite of [addMine]/[removeMine] that a chip tap and
  /// a picker selection both want.
  MessageReactionsEntity toggleMine(String emoji, {int? myUserId}) =>
      isMine(emoji)
      ? removeMine(emoji, myUserId: myUserId)
      : addMine(emoji, myUserId: myUserId);

  /// Optimistic whole-set replacement for `PUT .../reactions/` with
  /// `{ "reactions": [...] }` (§6.7.2). An empty [emojis] clears the user's
  /// reactions entirely.
  ///
  /// Expressed as remove-then-add rather than a rebuild so the counts of
  /// *other* people's reactions on the untouched groups survive intact.
  MessageReactionsEntity replaceMine(List<String> emojis, {int? myUserId}) {
    final wanted = emojis.take(ReactionLimits.maxPerUserPerMessage).toList();

    var next = this;
    for (final emoji in myEmojis) {
      if (!wanted.contains(emoji)) {
        next = next.removeMine(emoji, myUserId: myUserId);
      }
    }
    for (final emoji in wanted) {
      next = next.addMine(emoji, myUserId: myUserId);
    }

    return next;
  }

  @override
  List<Object?> get props => [
    messageId,
    groups,
    emoji,
    users,
    hasNext,
    nextUserId,
  ];
}
