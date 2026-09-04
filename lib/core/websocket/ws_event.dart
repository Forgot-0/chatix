import 'package:equatable/equatable.dart';

/// The chat WebSocket's server→client event vocabulary (api-docs §7.4).
///
/// A **sealed** hierarchy rather than a `@freezed` union, deliberately:
///
/// * These objects are only ever *decoded* — they arrive from the socket and
///   are consumed by controllers. Nothing serialises a [WSEvent] back to JSON
///   and almost nothing copies one, so `toJson`/`copyWith` (freezed's real
///   value-add) would be dead generated code.
/// * Dart 3's `sealed` already gives the one property that matters here:
///   the compiler rejects a `switch` that forgets a case. Adding a member to
///   this file therefore *breaks the build* at every consumer until it is
///   handled — which is exactly the guarantee the §7.4 table needs, since the
///   cost of silently dropping an event is a chat that quietly stops updating.
/// * The rest of the codebase models data with `Equatable` and hand-written
///   constructors (`MessageEntity`, `ChatEntity`, …) and has no `.freezed.dart`
///   anywhere; matching that keeps one idiom instead of two.
///
/// ## Envelope
///
/// A domain event arrives as `{ type, channel, payload, ts, enqueued_at }` —
/// the gateway unwraps the server-side `DeliveryDTO` and strips its `delivery`
/// block before sending (§7.4). `channel` **is** the chat id; it is not
/// repeated inside the delta.
///
/// `payload` is a `MessagePayloadWS`:
///
/// ```
/// { event_id, event_name, event: {…delta…}, message: MessageDTO | null,
///   reaction?: ReactionUpdateWSDTO | null }
/// ```
///
/// `event` is the **delta** — the handful of fields specific to that event type
/// (`reader_id`, `target_user_id`, `deleted_by`, …). A full `MessageDTO` rides
/// along only where it is genuinely needed (`new_message`, `message_edited`);
/// everywhere else `message` is `null` **and no refetch is required**, because
/// the delta already carries what changed. `attachment_success` is the one
/// exception to the whole shape — see its class doc.
///
/// Service (`ws.*`) frames do **not** share this envelope: each has its own
/// shape, and two of them (`ws.ping`, `ws.error`) omit `payload` entirely. That
/// is why there is no single base class holding a `payload` map — it would be a
/// lie for those two, and the parser would have to invent empty maps.
///
/// Instead every subclass exposes exactly the fields its own frame carries,
/// already unwrapped. Consumers never touch raw JSON — except
/// [NewMessage.message]/[MessageEdited.message], [ReactionUpdated.reaction],
/// [WsHistory.messages] and [WsUnknown.raw], all documented below.
///
/// ## Duplicates
///
/// Delivery is **at-least-once** (§7.4): the same frame can arrive twice.
/// [WSDomainEvent.eventId] is the dedup key, and `ChatSocketService` filters on
/// it before consumers see anything.
sealed class WSEvent extends Equatable {
  /// Wire value of `type`, kept for logging and for [WsUnknown] round-tripping.
  final String type;

  const WSEvent(this.type);

  @override
  List<Object?> get props => [type];
}

// ─────────────────────────── Domain events (§7.4) ───────────────────────────

/// Base for the events that describe something happening *inside a chat*.
///
/// Carries the envelope metadata common to all of them. [chatId] comes from
/// the frame's **`channel`** field (§7.4) — the id is deliberately not
/// duplicated inside the delta, so `channel` is the single source for it. It is
/// non-nullable here: every domain event in the §7.4 table is about a specific
/// chat, and a chatless `new_message` is unroutable, so surfacing one as
/// [WsUnknown] is more honest than a null nobody checks.
///
/// ⚠️ [eventId] is the **deduplication key** and it lives inside `payload`, not
/// on the envelope. Delivery is at-least-once (Redis Streams + `xautoclaim`
/// re-delivers records from a crashed gateway, §7.4), so the same frame can and
/// does arrive twice. [ChatSocketService] drops repeats by this value before
/// they reach consumers — which is why controllers may apply events blindly.
sealed class WSDomainEvent extends WSEvent {
  final String chatId;

  /// Backend's internal event name, e.g. `"chats.message.readed"`. From
  /// `payload.event_name`; useful in logs when correlating with server traces.
  final String? eventName;

  /// `payload.event_id` — the dedup key. See the class doc.
  final String? eventId;

  /// Server timestamp. Nullable because a malformed/absent `ts` must not cost
  /// us the event itself — the payload is what drives the UI.
  final DateTime? ts;

  const WSDomainEvent(
    super.type, {
    required this.chatId,
    this.eventName,
    this.eventId,
    this.ts,
  });

  @override
  List<Object?> get props => [type, chatId, eventName, eventId, ts];
}

/// Base for the three events that name a specific message.
///
/// Exists so [ChatSocketService] can do cursor bookkeeping — advance the
/// per-chat `last_seq` used by `resume` — without a `switch` over three
/// otherwise-unrelated classes, and without decoding a `MessageModel` it must
/// not import from `core/`.
sealed class WSMessageEvent extends WSDomainEvent {
  /// `payload.event.message_id`.
  final String messageId;

  /// `payload.event.seq` — the per-chat ordering/cursor value (§6.4).
  ///
  /// Nullable only defensively; the backend sends it on all three.
  final int? seq;

  const WSMessageEvent(
    super.type, {
    required super.chatId,
    required this.messageId,
    required this.seq,
    super.eventName,
    super.eventId,
    super.ts,
  });

  @override
  List<Object?> get props => [...super.props, messageId, seq];
}

/// `new_message` — a message was posted in the chat (api-docs §7.4).
///
/// One of only **two** events carrying a full `MessageDTO` (the other is
/// [MessageEdited]); everything else in §7.4 ships a delta and a `null`
/// message. So this needs no follow-up `GET`: decode [message] and upsert it —
/// see `ChatRealtimeMerge.upsertMessage`, whose id-based de-duplication also
/// makes the optimistic-send path safe when our own `POST /messages/` response
/// beat the event here.
///
/// [message] is kept as a **raw JSON map**, not a decoded model, for the same
/// reason [WsHistory.messages] is: this file is `core/` and must not import
/// `features/chat`'s `MessageModel`. The chat feature decodes it with
/// `MessageModel.fromJson` — the exact decoder it already uses for the REST
/// responses this same DTO appears in. It arrives complete: `profile`,
/// `attachments` (with download links), `reply_to`, `forwarded_from` and
/// `reactions` are all populated (§7.4).
final class NewMessage extends WSMessageEvent {
  /// `payload.event.sender_id`.
  final int? senderId;

  /// `payload.event.message_type` — the wire form (`"text"`, `"voice"`,
  /// `"video_note"`, …). Available without decoding [message], which is what
  /// makes a cheap "📷 Photo" list preview possible.
  final String? messageType;

  /// The complete `MessageDTO` as raw JSON. See class doc.
  final Map<String, dynamic> message;

  const NewMessage({
    required super.chatId,
    required super.messageId,
    required super.seq,
    required this.message,
    this.senderId,
    this.messageType,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('new_message');

  @override
  List<Object?> get props => [...super.props, senderId, messageType, message];
}

/// `message_edited` — [message] is the **post-edit** `MessageDTO` in full
/// (api-docs §7.4); decode and replace the local copy directly, no
/// `GET .../messages/{message_id}/` required.
///
/// ⚠️ [modifiedBy] is always the message's own author: editing is author-only
/// server-side, with no permission-based override (§6.4).
final class MessageEdited extends WSMessageEvent {
  /// `payload.event.modified_by`.
  final int? modifiedBy;

  /// The complete post-edit `MessageDTO` as raw JSON.
  final Map<String, dynamic> message;

  const MessageEdited({
    required super.chatId,
    required super.messageId,
    required super.seq,
    required this.message,
    this.modifiedBy,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('message_edited');

  @override
  List<Object?> get props => [...super.props, modifiedBy, message];
}

/// `message_deleted` (api-docs §7.4) — `payload.message` is `null` here, and
/// deliberately so: the delta carries everything needed to drop or tombstone
/// the local row by [WSMessageEvent.messageId], and re-fetching a deleted
/// message would only 404.
///
/// The deletion is soft server-side (`is_deleted = true`, §6.4) but the flag is
/// not part of the public `MessageDTO`, so this client treats the message as
/// gone.
///
/// [deletedBy] may be someone other than the author: `message:delete` lets
/// owner/admin/editor remove other people's messages (§9.1), which is what
/// makes "deleted by a moderator" renderable.
final class MessageDeleted extends WSMessageEvent {
  /// `payload.event.deleted_by`.
  final int? deletedBy;

  const MessageDeleted({
    required super.chatId,
    required super.messageId,
    required super.seq,
    this.deletedBy,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('message_deleted');

  @override
  List<Object?> get props => [...super.props, deletedBy];
}

/// `messages_read` — [readerId] has read this chat up to [seq] (api-docs §7.4).
///
/// Both fields are what make read receipts work: comparing [readerId] against
/// the signed-in user separates "I read this on another device" (advance our
/// own cursor, clear the unread badge) from "a peer read it" (move their
/// double-tick up to [seq]). Without the distinction a read receipt from
/// someone else would wrongly clear our own unread count.
final class MessagesRead extends WSDomainEvent {
  /// `payload.event.seq` — everything up to and including this seq is read.
  final int seq;

  /// `payload.event.reader_id` — who read it.
  final int readerId;

  const MessagesRead({
    required super.chatId,
    required this.seq,
    required this.readerId,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('messages_read');

  @override
  List<Object?> get props => [...super.props, seq, readerId];
}

/// `reaction_update` — a reaction was added, removed or replaced on a message
/// (api-docs §6.7.6, §7.4).
///
/// ⚠️ **[payload.message] is `null`; the data is in [reaction].** That block
/// (`ReactionUpdateWSDTO`) carries a **complete snapshot** of the message's
/// reaction groups, not a delta — so there is nothing to re-fetch and nothing
/// to accumulate. Replace the local groups for [messageId] with it, through
/// `MessageReactionsEntity.applySnapshot`.
///
/// ⚠️ The snapshot is **not personalised**: every group's `reacted_by_me` is
/// `false`, because one snapshot is broadcast to the whole chat (§6.7.6).
/// Assigning it verbatim would clear the current user's own highlighted chips
/// every time anyone else reacted — `applySnapshot` is what preserves them, and
/// is why [actorId] is exposed (comparing it against the signed-in id detects
/// our own action arriving from another device).
///
/// Under load the backend coalesces bursts into at most one frame per
/// `REACTIONS_COALESCE_WINDOW_MS` (500 ms) per message; the snapshot is always
/// the final state, and each group carries a monotonic `version` so an
/// out-of-order frame can be dropped rather than applied.
///
/// [reaction] stays a raw JSON map for the `core/`-must-not-import-`features/`
/// reason given on [NewMessage.message]; the feature decodes it with
/// `ReactionUpdateModel.fromJson`.
final class ReactionUpdated extends WSDomainEvent {
  /// `payload.event.message_id` — also repeated inside [reaction].
  final String messageId;

  /// `payload.event.actor_id` — who caused the change.
  final int? actorId;

  /// `payload.event.action` — `"add" | "remove" | "replace" | "update"`.
  /// Informational: the snapshot is authoritative regardless of the verb.
  final String? action;

  /// `payload.reaction` — the `ReactionUpdateWSDTO` snapshot. See class doc.
  final Map<String, dynamic> reaction;

  const ReactionUpdated({
    required super.chatId,
    required this.messageId,
    required this.reaction,
    this.actorId,
    this.action,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super(wireType);

  /// The wire value (api-docs §6.7.6, §7.4).
  static const String wireType = 'reaction_update';

  /// The raw domain-event name an older backend build fanned this out as,
  /// before `CHAT_EVENT_TO_WS_TYPE` gained an entry for it. Kept only so such a
  /// build is still recognised instead of falling into [WsUnknown]; the parser
  /// handles it identically to [wireType].
  static const String legacyWireType = 'chats.message.reaction_updated';

  @override
  List<Object?> get props => [...super.props, messageId, actorId, action, reaction];
}

/// `member_joined` — someone was added, or joined a public chat (api-docs
/// §7.4).
///
/// [roleId] is their starting chat role (§9.1): `5` (member) by default in a
/// group, `6` (viewer) in a channel, `4` (direct) in a 1:1 chat.
final class MemberJoined extends WSDomainEvent {
  /// `payload.event.user_id`.
  final int userId;

  /// `payload.event.role_id` — see §9.1 for the role table.
  final int? roleId;

  const MemberJoined({
    required super.chatId,
    required this.userId,
    this.roleId,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_joined');

  @override
  List<Object?> get props => [...super.props, userId, roleId];
}

/// `member_left` — a member left of their own accord (api-docs §7.4).
///
/// ⚠️ Also delivered **directly to the leaver**, who is no longer covered by
/// the chat's fan-out and may receive it without an active subscription
/// (§7.4). So a consumer must compare [userId] against the signed-in user:
/// ours means "drop this chat from the list and pop its screen", anyone else's
/// means "decrement the member count".
///
/// ⚠️ The chat's creator can never produce this event — `leave` is refused for
/// them (§6.2).
final class MemberLeft extends WSDomainEvent {
  /// `payload.event.user_id`.
  final int userId;

  const MemberLeft({
    required super.chatId,
    required this.userId,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_left');

  @override
  List<Object?> get props => [...super.props, userId];
}

/// `member_kick` — [targetUserId] was removed from the chat by [requesterId]
/// (api-docs §7.4). A kick is not a ban: they may re-join a public chat.
///
/// ⚠️ Also delivered directly to the kicked user, possibly without an active
/// subscription (§7.4) — compare [targetUserId] against the signed-in id to
/// tell "I was removed" from "someone else was".
final class MemberKick extends WSDomainEvent {
  /// `payload.event.target_user_id` — who was removed.
  final int targetUserId;

  /// `payload.event.requester_id` — who removed them.
  final int? requesterId;

  const MemberKick({
    required super.chatId,
    required this.targetUserId,
    this.requesterId,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_kick');

  @override
  List<Object?> get props => [...super.props, targetUserId, requesterId];
}

/// `member_banned` — covers **both directions**: [ban] is `true` for a ban and
/// `false` for an unban (api-docs §7.4).
///
/// ⚠️ A ban does more than mark the member: while it is in force the chat
/// disappears from the banned user's own `GET /chats/` list entirely, with no
/// marker (§6.3). Ours ([targetUserId] == signed-in id) with `ban: true` should
/// therefore be treated like a kick — remove the row — and `ban: false`
/// like a re-join.
///
/// ⚠️ Also delivered directly to the banned user, possibly without an active
/// subscription (§7.4).
final class MemberBanned extends WSDomainEvent {
  /// `payload.event.target_user_id`.
  final int targetUserId;

  /// `payload.event.requester_id`.
  final int? requesterId;

  /// `payload.event.ban` — `true` banned, `false` unbanned.
  final bool ban;

  const MemberBanned({
    required super.chatId,
    required this.targetUserId,
    required this.ban,
    this.requesterId,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_banned');

  @override
  List<Object?> get props => [...super.props, targetUserId, requesterId, ban];
}

/// `chat_created` — delivered to every listed member, not just the creator
/// (api-docs §7.4).
///
/// The delta is a summary, not a `ChatDTO`: enough to render a provisional row
/// (name, type, member count) while `GET /chats/{chat_id}/` fills in the rest.
/// A refetch is still the right move for the per-viewer fields — `me`,
/// `unread_count`, `last_read` — which a broadcast summary cannot carry.
final class ChatCreated extends WSDomainEvent {
  /// `payload.event.created_by`.
  final int? createdBy;

  /// `payload.event.name` — `null` for a direct chat, which has no name.
  final String? name;

  /// `payload.event.chat_type` — the wire form of `ChatType` (§6.1).
  final String? chatType;

  /// `payload.event.member_ids` — everyone added at creation.
  final List<int> memberIds;

  /// `payload.event.member_count`.
  final int? memberCount;

  const ChatCreated({
    required super.chatId,
    this.createdBy,
    this.name,
    this.chatType,
    this.memberIds = const [],
    this.memberCount,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('chat_created');

  @override
  List<Object?> get props => [
    ...super.props,
    createdBy,
    name,
    chatType,
    memberIds,
    memberCount,
  ];
}

/// `chat_updated` — chat settings changed (api-docs §7.4).
///
/// The delta mirrors `UpdateChatRequest` (§6.2) plus the reaction settings of
/// §6.7.5, so a local row can be patched field by field without a refetch.
///
/// ⚠️ **A `null` field means "not part of this change", not "cleared".**
/// `PATCH /chats/{chat_id}/` is a true partial update and offers no way to null
/// `name`/`description` back out (§6.2), so a `null` here can only ever mean
/// "untouched" — apply it with `??`, never by assignment. That is exactly what
/// `ChatRealtimeMerge.applyChatUpdated` does.
final class ChatUpdated extends WSDomainEvent {
  /// `payload.event.updated_by`.
  final int? updatedBy;

  final String? name;
  final String? description;
  final bool? isPublic;
  final bool? adminOnly;
  final int? slowModeSeconds;
  final Map<String, bool>? permissions;

  /// `payload.event.reactions_mode` — `"all" | "some" | "none"` (§6.7.5).
  final String? reactionsMode;

  /// `payload.event.allowed_reactions` — the whitelist used under
  /// `reactions_mode: "some"` (§6.7.5).
  final List<String>? allowedReactions;

  const ChatUpdated({
    required super.chatId,
    this.updatedBy,
    this.name,
    this.description,
    this.isPublic,
    this.adminOnly,
    this.slowModeSeconds,
    this.permissions,
    this.reactionsMode,
    this.allowedReactions,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('chat_updated');

  @override
  List<Object?> get props => [
    ...super.props,
    updatedBy,
    name,
    description,
    isPublic,
    adminOnly,
    slowModeSeconds,
    permissions,
    reactionsMode,
    allowedReactions,
  ];
}

/// `chat_deleted` — the chat is gone (api-docs §7.4). Drop it from the list and
/// pop the detail screen if it happens to be open.
///
/// Only the owner can trigger this (`chat:delete`, §9.1) — and for a chat's
/// creator it is the *only* way out, since `leave` is refused for them (§6.2).
final class ChatDeleted extends WSDomainEvent {
  /// `payload.event.deleted_by`.
  final int? deletedBy;

  const ChatDeleted({
    required super.chatId,
    this.deletedBy,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('chat_deleted');

  @override
  List<Object?> get props => [...super.props, deletedBy];
}

/// `attachment_success` — the backend finished processing uploads for [tokens]
/// after `POST .../attachments/upload-requests/confirm/` (api-docs §6.5, §7.4).
///
/// ⚠️ **Shape exception.** Its `payload` is an `AttachmentSuccessPayload`
/// (`{user_id, chat_id, tokens}`), not the `MessagePayloadWS` every other
/// domain event uses — there is no `event`/`event_name`/`message` block, and
/// `chat_id` lives *inside* the payload rather than only in `channel`.
///
/// ⚠️ **Unicast**: sent only to the uploading user, with
/// `delivery.require_subscription = false` — so it arrives without a chat
/// subscription, and other members never see it.
///
/// This is what lets the composer stop guessing: until it arrives for a token,
/// that attachment is still `pending` server-side. Use it to clear the per-file
/// spinner.
///
/// ⚠️ **There is no failure counterpart** (§6.5): processing that ends in
/// `error` is announced by nothing at all. A client that must be certain has to
/// read the attachment's `attachment_status` back off the sent message.
final class AttachmentSuccess extends WSDomainEvent {
  final int userId;

  /// The `upload_token`s now ready to pass to
  /// `SendMessageRequest.upload_tokens`.
  final List<String> tokens;

  const AttachmentSuccess({
    required super.chatId,
    required this.userId,
    required this.tokens,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('attachment_success');

  @override
  List<Object?> get props => [...super.props, userId, tokens];
}

// ─────────────────── Declared-but-never-published (§7.4) ───────────────────

/// Events present in the backend's `WSEventType` enum for which **no publisher
/// exists anywhere in the codebase** (api-docs §7.4, confirmed by grep):
/// `typing_start`, `typing_stop`, `call_started`, `call_ended`, `call_joined`,
/// `call_left`.
///
/// They are modelled — as one deliberately *inert* case rather than six
/// detailed ones — for a single reason: so that if the backend ever starts
/// sending them, the frame is recognised and logged instead of falling into
/// [WsUnknown]. That is the whole intended value.
///
/// ⚠️ **Do not build features on this class.** A "typing…" indicator or call
/// presence wired to it would be dead UI: the trigger never fires today, so
/// the indicator would never appear, and QA would be chasing a bug that is
/// really a missing backend publisher. When the backend does start publishing,
/// promote the relevant `type` to its own `final class` with a real payload —
/// the exhaustive `switch` will then point at every site needing an update.
final class WsUnimplementedEvent extends WSEvent {
  /// Envelope `chat_id`, when present.
  final String? chatId;

  /// Undecoded payload — no field is specified for these, so nothing is
  /// promised about its shape.
  final Map<String, dynamic> payload;

  const WsUnimplementedEvent(super.type, {this.chatId, this.payload = const {}});

  /// The six `type` values this class covers.
  static const Set<String> types = {
    'typing_start',
    'typing_stop',
    'call_started',
    'call_ended',
    'call_joined',
    'call_left',
  };

  @override
  List<Object?> get props => [type, chatId, payload];
}

// ─────────────────────────── Service frames (`ws.*`) ───────────────────────────

/// `ws.ready` — first frame after the handshake (api-docs §7.2/§7.4).
///
/// Source of the heartbeat contract. [heartbeatInterval] is how often the
/// server will send `ws.ping`; [heartbeatTimeout] is how long we may stay
/// silent before it closes us with **1001**. Both are read from here rather
/// than hard-coded, so a server-side tuning change doesn't strand old clients.
final class WsReady extends WSEvent {
  final String connectionId;
  final String gatewayId;

  /// Seconds between server `ws.ping`s (server default 30).
  final int heartbeatInterval;

  /// Seconds of client silence tolerated before close 1001 (server default 75).
  final int heartbeatTimeout;

  /// `reconnect.mode`, e.g. `"last_seq_per_chat"` — the server telling us which
  /// resume strategy it supports.
  final String? reconnectMode;

  /// `reconnect.op`, e.g. `"resume"` — the command to send after reconnecting.
  final String? reconnectOp;

  const WsReady({
    required this.connectionId,
    required this.gatewayId,
    required this.heartbeatInterval,
    required this.heartbeatTimeout,
    this.reconnectMode,
    this.reconnectOp,
  }) : super('ws.ready');

  @override
  List<Object?> get props => [
    type,
    connectionId,
    gatewayId,
    heartbeatInterval,
    heartbeatTimeout,
    reconnectMode,
    reconnectOp,
  ];
}

/// `ws.subscribed` — acknowledgement of `subscribe` **or** of one chat inside a
/// `resume` (api-docs §7.4). A `resume` with N cursors therefore produces N of
/// these, not one.
///
/// [lastSeq] is the server's idea of the newest `seq` in that chat, and is
/// `null` for an empty chat — which is why it is nullable rather than `0`.
final class WsSubscribed extends WSEvent {
  final String chatId;
  final int? lastSeq;
  final DateTime? ts;

  const WsSubscribed({required this.chatId, this.lastSeq, this.ts})
    : super('ws.subscribed');

  @override
  List<Object?> get props => [type, chatId, lastSeq, ts];
}

/// `ws.unsubscribed` — acknowledgement of `unsubscribe`.
final class WsUnsubscribed extends WSEvent {
  final String chatId;
  final DateTime? ts;

  const WsUnsubscribed({required this.chatId, this.ts})
    : super('ws.unsubscribed');

  @override
  List<Object?> get props => [type, chatId, ts];
}

/// `ws.history` — gap fill sent after `ws.subscribed`, but **only when the
/// `subscribe`/`resume` included a `last_seq`/cursor** (api-docs §7.4).
///
/// ⚠️ The one server→client frame that carries **full message data**: unlike
/// `new_message`, [messages] are complete `MessageDTO`s (§6.4) with attachments
/// and download links already attached. Insert them directly — re-fetching
/// them one by one would be pointless traffic.
///
/// [messages] stays as raw JSON maps on purpose: `MessageDTO` belongs to
/// `features/chat/data/models`, and a `core/` service must not import a
/// feature. The chat layer maps them with `MessageModel.fromJson`, reusing the
/// exact same decoder as the REST endpoints.
///
/// [hasMore] means the gap was larger than one batch: subscribe again (or page
/// via `GET /messages/`) from [nextLastSeq] until it comes back `false`.
final class WsHistory extends WSEvent {
  final String chatId;

  /// The `seq` the server replayed *after* — echoes the cursor we sent.
  final int afterSeq;

  /// Full `MessageDTO` objects, undecoded. See class doc.
  final List<Map<String, dynamic>> messages;

  final bool hasMore;

  /// Cursor to continue from when [hasMore] is `true`.
  final int? nextLastSeq;

  final DateTime? ts;

  const WsHistory({
    required this.chatId,
    required this.afterSeq,
    required this.messages,
    required this.hasMore,
    this.nextLastSeq,
    this.ts,
  }) : super('ws.history');

  @override
  List<Object?> get props => [
    type,
    chatId,
    afterSeq,
    messages,
    hasMore,
    nextLastSeq,
    ts,
  ];
}

/// `ws.pong` — reply to our `{"op":"ping"}`. Proof the socket is alive
/// end-to-end, which a TCP connection alone does not give us.
final class WsPong extends WSEvent {
  const WsPong() : super('ws.pong');
}

/// `ws.ping` — the server's heartbeat, every `heartbeat_interval` seconds.
///
/// ⚠️ Shape exception: this frame has **no `payload` wrapper** (api-docs §7.4),
/// so a parser that reaches for `json['payload']['connection_id']` gets a null
/// crash. [connectionId] is read from the top level.
///
/// Must be answered with `{"op":"pong"}` — see [WsReady.heartbeatTimeout].
final class WsPing extends WSEvent {
  final String? connectionId;
  final DateTime? ts;

  const WsPing({this.connectionId, this.ts}) : super('ws.ping');

  @override
  List<Object?> get props => [type, connectionId, ts];
}

/// `ws.error` with `code: "BAD_COMMAND"` or `"BAD_FRAME"` — **our** bug: a
/// frame the server could not parse or a command it does not accept.
///
/// ⚠️ No `payload` wrapper; `code`/`detail` sit at the top level
/// (api-docs §7.4). [detail] is the server's human-readable reason and is the
/// only thing that makes these debuggable, so it is kept required-ish here
/// (empty string when absent) rather than dropped.
///
/// Not user-facing: never surface this as a snackbar. Log it, fix the client.
/// Notably **not** raised for a `resume` with >20 cursors — that one escapes as
/// an unwrapped `MAX_LIMIT_CURSOR` server-side and may kill the connection
/// outright (§7.3), which is why the service clamps before sending.
final class WsErrorBadCommand extends WSEvent {
  /// `"BAD_COMMAND"` or `"BAD_FRAME"`.
  final String code;

  final String detail;

  /// Present on real frames but not guaranteed; kept optional so a missing
  /// `ts` never costs us the error itself.
  final DateTime? ts;

  const WsErrorBadCommand({required this.code, required this.detail, this.ts})
    : super('ws.error');

  @override
  List<Object?> get props => [type, code, detail, ts];
}

/// `ws.error` with `code: "NOT_CHAT_MEMBER"` — we tried to `subscribe`/`resume`
/// to a chat we are not a member of, or were banned from (api-docs §7.4).
///
/// A separate class from [WsErrorBadCommand] because it means something
/// completely different and demands a different reaction: this is *legitimate
/// server state*, not a malformed command. The right response is to stop
/// retrying that chat, drop it from the local cursor map (otherwise every
/// reconnect re-sends the doomed cursor forever) and refresh the chat list.
///
/// ⚠️ Carries no useful `detail` in practice — it does not say *which* chat
/// was rejected, so correlate it with the `subscribe` you just sent.
final class WsErrorNotChatMember extends WSEvent {
  /// Always `"NOT_CHAT_MEMBER"`.
  final String code;

  final DateTime? ts;

  /// Usually absent for this code; retained for completeness.
  final String? detail;

  const WsErrorNotChatMember({required this.code, this.ts, this.detail})
    : super('ws.error');

  @override
  List<Object?> get props => [type, code, ts, detail];
}

// ───────────────────────── Client-side internal events ─────────────────────────

/// **Not a server frame.** Injected by `ChatSocketService` when the socket
/// closes with **1008** (missing/invalid token, api-docs §7.1).
///
/// Exists because 1008 is the one close code that auto-reconnect must *not*
/// answer: the handshake is rejected before `websocket.accept()`, so retrying
/// with the same dead `access_token` produces a tight reconnect loop that
/// hammers the server and never recovers. The loop stops and this event asks
/// the app layer to refresh the token or sign out, then reconnect explicitly.
///
/// Also mirrored on `ChatSocketService.isTokenInvalid` for listeners that
/// aren't consuming the event stream.
final class WsAuthInvalid extends WSEvent {
  /// Raw close code (1008 in practice), for logging.
  final int? closeCode;
  final String? closeReason;

  const WsAuthInvalid({this.closeCode, this.closeReason})
    : super('client.auth_invalid');

  @override
  List<Object?> get props => [type, closeCode, closeReason];
}

/// A frame whose `type` this client does not know — a new backend event, a
/// typo, or a protocol version drift.
///
/// The reason this class exists at all: the alternative (throwing) means one
/// unrecognised frame from a newer backend takes the whole chat down. The
/// backend is explicitly documented as having events we don't consume, so
/// unknown types are an *expected* condition, not an exceptional one.
/// [raw] is preserved verbatim so a log line is enough to implement it later.
final class WsUnknown extends WSEvent {
  final Map<String, dynamic> raw;

  /// `type` when the frame had one at all; `'<missing>'` when it did not.
  const WsUnknown({required String type, required this.raw}) : super(type);

  @override
  List<Object?> get props => [type, raw];
}
