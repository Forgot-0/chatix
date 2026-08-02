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
/// Domain events share the §7.4 envelope: `type`, `chat_id`, `payload`, `ts`,
/// optional `event_name`/`event_id`/`seq`. Service (`ws.*`) frames **do not** —
/// each has its own shape, and two of them omit `payload` entirely. That is why
/// there is no single "envelope" base class holding a `payload` map: it would be
/// a lie for `ws.ping` and `ws.error`, and the parser would have to invent
/// empty maps to satisfy it.
///
/// Instead every subclass exposes exactly the fields its own frame carries,
/// already unwrapped from `payload`. Consumers never touch raw JSON — except
/// [WsHistory.messages] and [WsUnknown.raw], both documented below.
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
/// Carries the envelope metadata common to all of them. `chatId` is
/// non-nullable here even though §7.4 types the envelope field as
/// `string | null`: every domain event in the table is about a specific chat,
/// and most also repeat the id inside `payload`. The parser resolves the two
/// (envelope first, `payload.chat_id` as fallback) and rejects a domain frame
/// that has neither — a chatless `new_message` is unroutable, so surfacing it
/// as [WsUnknown] is more honest than a null nobody checks.
sealed class WSDomainEvent extends WSEvent {
  final String chatId;

  /// Backend's internal event name, e.g. `"chats.message.sent"`. Optional on
  /// the wire; useful in logs when correlating with server traces.
  final String? eventName;

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

/// `new_message` — ⚠️ **a notification, not the message** (api-docs §7.4/§7.5).
///
/// The payload is `{message_id, seq, sender_id, message_type}` and contains
/// **no content, no attachments, no author profile**. Rendering it directly as
/// a bubble is the single most likely mistake against this protocol.
///
/// The three correct reactions, in order of preference:
///
/// 1. **It's our own message** (`senderId == me`) — do nothing. The full
///    message was already inserted optimistically from the `POST /messages/`
///    response (§6.4). Re-fetching it would be a wasted round-trip, and
///    appending it would duplicate the bubble.
/// 2. **The chat is on screen** — fetch it: `GET /chats/{chat_id}/messages/
///    {message_id}/`, then insert by [seq].
/// 3. **The chat is not on screen** — do *not* fetch. Bump the list row's
///    unread badge and `last_activity_at` and stop there; the content is paid
///    for when (and only if) the user opens that chat.
final class NewMessage extends WSDomainEvent {
  final String messageId;

  /// Per-chat monotonic sequence number — the ordering key and the value to
  /// feed back as `subscribe.last_seq` / `resume.cursors` after a reconnect.
  final int seq;

  /// `null` for `system` messages, which have no human author.
  final int? senderId;

  /// `MessageDTO.type` on the wire (`text`/`image`/`file`/…). A raw string
  /// here rather than the chat feature's `MessageType` enum: this file is
  /// `core/` and must not depend on `features/chat`. The feature maps it.
  final String messageType;

  const NewMessage({
    required super.chatId,
    required this.messageId,
    required this.seq,
    required this.senderId,
    required this.messageType,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('new_message');

  @override
  List<Object?> get props => [...super.props, messageId, seq, senderId, messageType];
}

/// `message_edited` — again ids only; the new `content` must be re-fetched
/// with `GET .../messages/{message_id}/` (api-docs §7.4).
final class MessageEdited extends WSDomainEvent {
  final String messageId;
  final int seq;
  final int modifiedBy;

  const MessageEdited({
    required super.chatId,
    required this.messageId,
    required this.seq,
    required this.modifiedBy,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('message_edited');

  @override
  List<Object?> get props => [...super.props, messageId, seq, modifiedBy];
}

/// `message_deleted` — the only event whose payload is *sufficient on its own*:
/// [messageId] is all a store needs to drop or tombstone the row. Never
/// re-fetch this one; the message is gone and the request would 404.
final class MessageDeleted extends WSDomainEvent {
  final String messageId;
  final int seq;
  final int deletedBy;

  const MessageDeleted({
    required super.chatId,
    required this.messageId,
    required this.seq,
    required this.deletedBy,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('message_deleted');

  @override
  List<Object?> get props => [...super.props, messageId, seq, deletedBy];
}

/// `messages_read` — [readerId] has read everything up to and including [seq].
///
/// Fires for *every* member including ourselves (our own `POST
/// /messages/read/` echoes back), so consumers must compare [readerId] against
/// the current user before treating it as "someone else read my message".
final class MessagesRead extends WSDomainEvent {
  final int seq;
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

/// `member_joined` — a member was added or joined a public chat.
final class MemberJoined extends WSDomainEvent {
  final int userId;

  /// `ChatRolesEnum` id (api-docs §9.1) — drives the §10.6 permission gates.
  final int roleId;

  const MemberJoined({
    required super.chatId,
    required this.userId,
    required this.roleId,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_joined');

  @override
  List<Object?> get props => [...super.props, userId, roleId];
}

/// `member_left` — the member left of their own accord (contrast [MemberKick]).
final class MemberLeft extends WSDomainEvent {
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

/// `member_kick` — [targetUserId] was removed by [requesterId].
///
/// ⚠️ Singular `member_kick`, not `member_kicked` — the wire name breaks the
/// past-tense pattern of its neighbours (api-docs §7.4).
final class MemberKick extends WSDomainEvent {
  final int requesterId;
  final int targetUserId;

  const MemberKick({
    required super.chatId,
    required this.requesterId,
    required this.targetUserId,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_kick');

  @override
  List<Object?> get props => [...super.props, requesterId, targetUserId];
}

/// `member_banned` — ⚠️ covers **both** ban and *un*ban; [ban] says which.
/// Treating this event as "banned" unconditionally silently drops unbans.
final class MemberBanned extends WSDomainEvent {
  final int requesterId;
  final int targetUserId;

  /// `true` = banned, `false` = unbanned.
  final bool ban;

  const MemberBanned({
    required super.chatId,
    required this.requesterId,
    required this.targetUserId,
    required this.ban,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_banned');

  @override
  List<Object?> get props => [...super.props, requesterId, targetUserId, ban];
}

/// `chat_created` — delivered to **every** listed member, not just the creator
/// (api-docs §7.4), so it is how an invitee learns a chat exists without
/// polling `GET /chats/`.
///
/// The payload is a summary, not a `ChatDTO`: it has [name], [chatType] and
/// [memberCount] but no `me` membership and no permissions. Enough to insert a
/// provisional row in the chat list; open the chat for the full object.
final class ChatCreated extends WSDomainEvent {
  final int createdBy;

  /// `null` for direct chats, which derive their title from the peer.
  final String? name;

  final List<int> memberIds;

  /// `ChatType` wire value (`direct`/`group`/`supergroup`/`channel`) — a raw
  /// string for the same `core`-must-not-import-`features` reason as
  /// [NewMessage.messageType].
  final String chatType;

  final int memberCount;

  const ChatCreated({
    required super.chatId,
    required this.createdBy,
    required this.name,
    required this.memberIds,
    required this.chatType,
    required this.memberCount,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('chat_created');

  @override
  List<Object?> get props => [
    ...super.props,
    createdBy,
    name,
    memberIds,
    chatType,
    memberCount,
  ];
}

/// `chat_updated` — settings changed.
///
/// ⚠️ [name] and [description] being `null` is **ambiguous** on this event:
/// the wire cannot distinguish "cleared" from "unchanged". Consumers should
/// treat a `chat_updated` as a hint to refresh the chat rather than blindly
/// overwriting local fields with nulls.
final class ChatUpdated extends WSDomainEvent {
  final int updatedBy;
  final String? name;
  final String? description;
  final bool isPublic;
  final bool adminOnly;
  final int slowModeSeconds;

  /// Chat-level permission map (api-docs §9.1) — feeds the §10.6 UI gates.
  final Map<String, bool> permissions;

  const ChatUpdated({
    required super.chatId,
    required this.updatedBy,
    required this.name,
    required this.description,
    required this.isPublic,
    required this.adminOnly,
    required this.slowModeSeconds,
    required this.permissions,
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
  ];
}

/// `attachment_success` — the backend finished processing uploads for
/// [tokens] after `POST .../attachments/confirm/` (api-docs §6.5, §7.4).
///
/// ⚠️ Unicast: sent **only to the uploading user**, not to the chat's
/// subscribers — so it needs no chat subscription to arrive, and other members
/// never see it.
///
/// This is the event that lets the composer stop guessing: until it arrives for
/// a token, that attachment is still `pending` server-side and a message sent
/// with it would render as a broken thumbnail. Use it to clear the per-file
/// spinner and re-enable send.
final class AttachmentSuccess extends WSDomainEvent {
  final int userId;

  /// The `upload_token`s now ready to pass to `SendMessageRequest.upload_tokens`.
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

/// `chat_deleted` — the chat is gone. Consumers should drop it from the list
/// and pop the detail screen if it happens to be open.
final class ChatDeleted extends WSDomainEvent {
  final int deletedBy;

  const ChatDeleted({
    required super.chatId,
    required this.deletedBy,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('chat_deleted');

  @override
  List<Object?> get props => [...super.props, deletedBy];
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
