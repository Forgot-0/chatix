import 'package:equatable/equatable.dart';

/// Message reactions (api-docs §6.7).
///
/// ## ⚠️ Single-choice, not a set
///
/// The backend holds a `UniqueConstraint(message_id, user_id)`, so a user has
/// **exactly one** reaction on a message — never a set of emoji like Slack or
/// Telegram (api-docs §6.7.2). Three consequences this file is shaped around:
///
/// * `PUT .../reactions/{new}/` while another emoji is already set is a
///   *replacement*, not an addition: the old counter drops, the new one rises
///   and the backend publishes **two** `reaction_update` events.
/// * At most one [ReactionSummaryEntity] in a message's [summaries] can ever
///   have `reactedByMe == true` — see [MessageReactionsEntity.myEmoji], which
///   is the only supported way to ask "what did I react with".
/// * Nothing here models "my reactions" as a collection. Adding one later
///   would not be an extension of this model but a contradiction of it.
///
/// `MessageDTO` carries **no** reactions field (api-docs §6.4), so a summary
/// is never delivered with the message: it is fetched separately when a chat's
/// history is opened and then kept current by the `reaction_update` WS event
/// (§6.7.5) — which, since that event's own payload revision, means a forced
/// re-fetch rather than a local patch; see `ChatDetailController._onReactionUpdated`.

/// `ReactionSummaryDTO` (api-docs §6.7.3) — one emoji "chip" under a message.
class ReactionSummaryEntity extends Equatable {
  /// The emoji itself, 1..32 characters on the wire.
  ///
  /// Kept as the raw string, unescaped: it is a display value here, and the
  /// URL-encoding it needs as a path parameter is applied at the data-source
  /// boundary rather than baked into the entity (which would then render the
  /// escaped form).
  final String emoji;

  /// How many people reacted with [emoji]. Always the **absolute** count —
  /// the WS event carries absolute counts too, never deltas (§6.7.5).
  final int count;

  /// Whether the *current user's* one reaction is this emoji.
  ///
  /// At most one summary in a list may have this set; see the class doc.
  final bool reactedByMe;

  const ReactionSummaryEntity({
    required this.emoji,
    required this.count,
    required this.reactedByMe,
  });

  ReactionSummaryEntity copyWith({int? count, bool? reactedByMe}) {
    return ReactionSummaryEntity(
      emoji: emoji,
      count: count ?? this.count,
      reactedByMe: reactedByMe ?? this.reactedByMe,
    );
  }

  @override
  List<Object?> get props => [emoji, count, reactedByMe];
}

/// `ReactionUserDTO` (api-docs §6.7.3) — one row of the "who reacted" sheet.
///
/// [emoji] is repeated on every row even though the sheet is opened per-emoji,
/// because the endpoint can be called without `?emoji=` in principle; it is
/// also the user's *only* reaction on that message, by the single-choice rule.
class ReactionUserEntity extends Equatable {
  final int userId;
  final String emoji;

  const ReactionUserEntity({required this.userId, required this.emoji});

  @override
  List<Object?> get props => [userId, emoji];
}

/// `MessageReactionsDTO` (api-docs §6.7.3) — the response of
/// `GET .../reactions/`, which serves **two** different purposes:
///
/// 1. **Without `?emoji=`** — the chip summary for a message. [summaries] is
///    populated, [users] is empty and [hasNext] is `false`.
/// 2. **With `?emoji=👍`** — additionally a paginated list of who reacted, for
///    the long-press sheet. [summaries] is still sent in full.
///
/// Both shapes are one DTO server-side, so they are one entity here; [emoji]
/// echoes the query parameter and is the discriminator between them.
class MessageReactionsEntity extends Equatable {
  /// ⚠️ A plain `string` on the wire, not a UUID-typed field (api-docs
  /// §6.7.3) — matching [MessageEntity.id], which is also a string.
  final String messageId;

  /// Every emoji on this message with its absolute count. Complete in both
  /// modes, and the only thing the chip row needs.
  final List<ReactionSummaryEntity> summaries;

  /// Echo of the `?emoji=` query parameter; `null` in summary-only mode.
  final String? emoji;

  /// Who reacted with [emoji] — **non-empty only when [emoji] is set**.
  final List<ReactionUserEntity> users;

  /// Whether another page of [users] exists.
  final bool hasNext;

  /// Cursor for the next page — pass back as `cursor_user_id`. `null` when
  /// [hasNext] is false.
  final int? nextUserId;

  const MessageReactionsEntity({
    required this.messageId,
    this.summaries = const [],
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

  bool get isEmpty => summaries.isEmpty;

  /// The current user's one reaction, or `null` if they haven't reacted.
  ///
  /// Singular by design — the single-choice constraint (see the library doc)
  /// means there can never be a second one.
  String? get myEmoji {
    for (final summary in summaries) {
      if (summary.reactedByMe) return summary.emoji;
    }
    return null;
  }

  MessageReactionsEntity copyWith({
    List<ReactionSummaryEntity>? summaries,
    String? emoji,
    List<ReactionUserEntity>? users,
    bool? hasNext,
    int? nextUserId,
    bool clearNextUserId = false,
  }) {
    return MessageReactionsEntity(
      messageId: messageId,
      summaries: summaries ?? this.summaries,
      emoji: emoji ?? this.emoji,
      users: users ?? this.users,
      hasNext: hasNext ?? this.hasNext,
      nextUserId: clearNextUserId ? null : (nextUserId ?? this.nextUserId),
    );
  }

  /// Applies an absolute reaction count as if a `reaction_update` event had
  /// carried it directly.
  ///
  /// ⚠️ **Not currently called from anywhere.** This modelled the *old*
  /// `chats.message.reaction_updated` payload, which carried exactly
  /// `{emoji, count, changed_by}` (api-docs §6.7.5, pre-revision). The current
  /// `reaction_update` event carries none of those — only the generic
  /// `{chat, message}` pair, and `MessageDTO` has no reactions field at all
  /// (§6.4) — so `ChatDetailController` now reacts to it by re-fetching the
  /// summary wholesale (`GET .../reactions/`) rather than by calling this
  /// method. Kept, rather than deleted, in case a future backend revision
  /// restores a per-emoji delta on the event and this becomes applicable
  /// again; the three rules below would still be the correct ones if it does.
  ///
  /// * `count` is absolute, never a delta — it is assigned, not added. The
  ///   backend debounces fan-out, so a delta-based client would drift
  ///   permanently after one dropped frame.
  /// * `count == 0` removes the chip entirely rather than rendering a zero.
  /// * When [isMine] (the event's `changed_by` is us) the local `reactedByMe`
  ///   is **preserved**: it was already set optimistically when the PUT/DELETE
  ///   was issued, and the event says nothing about who is looking. Letting
  ///   the event decide would make our own chip flicker off and back on.
  MessageReactionsEntity applyUpdate({
    required String emoji,
    required int count,
    required bool isMine,
  }) {
    final next = <ReactionSummaryEntity>[];
    var found = false;

    for (final summary in summaries) {
      if (summary.emoji != emoji) {
        next.add(summary);
        continue;
      }
      found = true;
      if (count <= 0) continue; // chip disappears
      next.add(summary.copyWith(count: count));
    }

    if (!found && count > 0) {
      next.add(
        ReactionSummaryEntity(
          emoji: emoji,
          count: count,
          // Somebody else's reaction created this chip. If it were ours, the
          // optimistic update has already inserted it with `reactedByMe:
          // true`, so we would have taken the branch above.
          reactedByMe: isMine,
        ),
      );
    }

    return copyWith(summaries: next);
  }

  /// Optimistic local toggle for the current user's own reaction, applied the
  /// moment a `PUT`/`DELETE` is issued rather than when the WS event returns
  /// (api-docs §6.7.2 recommends exactly this).
  ///
  /// Because the model is single-choice, setting a new emoji must *also*
  /// decrement the previous one in the same step — that is the whole reason
  /// this lives on the entity instead of being open-coded in the widget.
  MessageReactionsEntity toggleMine(String emoji) {
    final previous = myEmoji;
    final next = <ReactionSummaryEntity>[];

    // Tapping the emoji already set is a removal.
    final isRemoval = previous == emoji;

    for (final summary in summaries) {
      if (summary.emoji == previous) {
        final count = summary.count - 1;
        if (count > 0) {
          next.add(summary.copyWith(count: count, reactedByMe: false));
        }
        continue;
      }
      next.add(summary);
    }

    if (isRemoval) return copyWith(summaries: next);

    final index = next.indexWhere((s) => s.emoji == emoji);
    if (index >= 0) {
      next[index] = next[index].copyWith(
        count: next[index].count + 1,
        reactedByMe: true,
      );
    } else {
      next.add(
        ReactionSummaryEntity(emoji: emoji, count: 1, reactedByMe: true),
      );
    }

    return copyWith(summaries: next);
  }

  @override
  List<Object?> get props => [
    messageId,
    summaries,
    emoji,
    users,
    hasNext,
    nextUserId,
  ];
}
