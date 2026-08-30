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
/// [WSChatMessageEvent.chat]/[WSChatMessageEvent.message], [WsHistory.messages]
/// and [WsUnknown.raw], all documented below.
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

/// Base for the domain events whose payload is the generic `MessagePayloadWS`
/// envelope (api-docs §7.4, revised): `{ chat: ChatDTO, message: MessageDTO }`.
///
/// ## This replaces a whole family of per-event payload shapes
///
/// Before this revision, `new_message`, `member_kick`, `chat_updated` and
/// friends each carried their own minimal, hand-picked fields
/// (`message_id`/`seq`, `target_user_id`/`requester_id`, `updated_by`/`name`/…).
/// The backend's `ChatDeliveryRouter` no longer does that: every domain event
/// it routes — regardless of which one it semantically is — re-fetches the
/// current `ChatDTO` and `MessageDTO` and ships those two objects, full stop.
/// `event_name`/`event_id` from the original domain event do not survive that
/// trip either (§7.4).
///
/// [chat] and [message] are kept as **raw JSON maps**, not decoded models, for
/// the same reason [WsHistory.messages] is: this file is `core/` and must not
/// import `features/chat`'s `ChatModel`/`MessageModel`. The chat feature
/// decodes them with `ChatModel.fromJson`/`MessageModel.fromJson` — the exact
/// decoders it already uses for the REST responses these DTOs also appear in.
///
/// ## The real cost: several events lost fields with no replacement
///
/// A handful of scalar fields the old payloads carried have **no equivalent**
/// in `{chat, message}` and the docs say so plainly:
///
/// * `messages_read` no longer says *who* read up to [messageSeq] — there is
///   no `reader_id` anywhere in a `ChatDTO`/`MessageDTO`. A client cannot tell
///   "it was me, on another device" from "it was a peer" any more.
/// * `member_kick`/`member_banned`/`member_left` no longer name the target,
///   the requester, or (for bans) the ban/unban direction.
/// * `reaction_update` (renamed from the old `chats.message.reaction_updated`
///   — see [ReactionUpdated]) no longer carries `emoji`/`count`/`changed_by`,
///   and — despite a claim in api-docs §6.7.5 that the message "already
///   contains its reactions" — §6.4 is explicit and repeated elsewhere that
///   `MessageDTO` has **no** `reactions` field at all. That §6.7.5 comment
///   appears to be a documentation error; nothing this client can decode
///   contradicts §6.4's warning, so this client does not rely on it.
///
/// The feature layer's job in each of these cases is spelled out on the
/// consuming controller, not here: broadly, "refetch the authoritative state
/// instead of guessing" (`ChatRealtimeMerge`, `ChatDetailController`,
/// `ChatListController`).
sealed class WSChatMessageEvent extends WSDomainEvent {
  /// Raw `ChatDTO` JSON (api-docs §6.2). Decode with `ChatModel.fromJson`.
  final Map<String, dynamic> chat;

  /// Raw `MessageDTO` JSON (api-docs §6.4). Decode with `MessageModel.fromJson`.
  final Map<String, dynamic> message;

  const WSChatMessageEvent(
    super.type, {
    required super.chatId,
    required this.chat,
    required this.message,
    super.eventName,
    super.eventId,
    super.ts,
  });

  /// `message.id`, read without a full model decode.
  String? get messageId => message['id'] as String?;

  /// `message.seq` — the per-chat ordering/cursor value (api-docs §6.4).
  ///
  /// Exposed here, in `core/`, because [ChatSocketService] needs it for cursor
  /// bookkeeping on `new_message`/`message_edited`/`message_deleted` and must
  /// not import a decoded `MessageModel` (see that class's doc).
  int? get messageSeq {
    final value = message['seq'];

    if (value is int) {
      return value;
    }

    if (value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) {
      return value.toInt();
    }

    return null;
  }

  @override
  List<Object?> get props => [...super.props, chat, message];
}

/// `new_message` (api-docs §7.4, revised).
///
/// ⚠️ **No longer just a notification.** Before this revision the payload was
/// `{message_id, seq, sender_id, message_type}` with no content, and the §7.5
/// playbook was built around fetching the body separately. That playbook is
/// gone: [message] is now a **complete `MessageDTO`**, content and attachments
/// included, so the correct reaction is simply to decode it and upsert it —
/// see `ChatRealtimeMerge.upsertMessage`. No follow-up `GET` is needed, own
/// message or not; `upsertMessage`'s id-based de-duplication already makes the
/// optimistic-send path safe.
final class NewMessage extends WSChatMessageEvent {
  const NewMessage({
    required super.chatId,
    required super.chat,
    required super.message,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('new_message');
}

/// `message_edited` (api-docs §7.4, revised) — [message] is the **post-edit**
/// `MessageDTO` in full; decode and replace the local copy directly, no
/// `GET .../messages/{message_id}/` required any more.
final class MessageEdited extends WSChatMessageEvent {
  const MessageEdited({
    required super.chatId,
    required super.chat,
    required super.message,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('message_edited');
}

/// `message_deleted` (api-docs §7.4, revised).
///
/// [message] is a `MessageDTO` reflecting the deleted message; §6.4 documents
/// the deletion as soft (`is_deleted = true` server-side) but that flag is not
/// listed in the public `MessageDTO` shape, so this client does not depend on
/// its presence. Only [WSChatMessageEvent.messageId] is treated as reliable —
/// enough to drop or tombstone the local row (`ChatRealtimeMerge.
/// applyMessageDeleted`), which is exactly the "state, not content" this event
/// needs to convey.
final class MessageDeleted extends WSChatMessageEvent {
  const MessageDeleted({
    required super.chatId,
    required super.chat,
    required super.message,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('message_deleted');
}

/// `messages_read` (api-docs §7.4, revised) — someone read up to
/// [WSChatMessageEvent.messageSeq].
///
/// ⚠️ **The reader's identity is gone.** The old payload's `reader_id` has no
/// equivalent in `{chat, message}` — neither DTO says who issued the read
/// receipt. That makes this event **unattributable**: a consumer can no longer
/// tell "I read this on another device" from "a peer read it", which is
/// exactly the distinction `ChatDetailState.peerReadSeq` and the chat list's
/// unread-badge clearing depended on. Both now treat this event as inert
/// rather than guess at attribution — see `ChatDetailController._onEvent`'s
/// `MessagesRead` case and `ChatListController._onEvent`'s. Our own read
/// cursor keeps advancing exactly as before, but only from *our own* actions
/// (opening a chat, sending, receiving), never from this event.
final class MessagesRead extends WSChatMessageEvent {
  const MessagesRead({
    required super.chatId,
    required super.chat,
    required super.message,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('messages_read');
}

/// A reaction counter on some message changed (api-docs §6.7.5, revised).
///
/// ⚠️ **Wire `type` changed.** This used to arrive as the raw domain event
/// name `"chats.message.reaction_updated"`, because the backend's
/// `CHAT_EVENT_TO_WS_TYPE` table had no entry for it. It now arrives as the
/// short alias `"reaction_update"`, matching every other domain event —
/// [wireType] is kept only so old server builds and this file's tests share
/// one named constant instead of a bare string literal.
///
/// ⚠️ **No more `emoji`/`count`/`changed_by`.** The old payload gave an
/// absolute per-emoji count that could be applied to `MessageReactionsEntity`
/// with no extra request. That is gone: [message] carries no reactions field
/// at all (§6.4 — see the warning on [WSChatMessageEvent]), so this event now
/// only means "the reaction summary for [WSChatMessageEvent.messageId] is
/// stale" — the consumer must re-fetch it with `GET .../reactions/` (§6.7.1).
/// `ChatDetailController._onReactionUpdated` does exactly that, forcing a
/// refresh even for a message whose summary was already loaded.
final class ReactionUpdated extends WSChatMessageEvent {
  const ReactionUpdated({
    required super.chatId,
    required super.chat,
    required super.message,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super(wireType);

  /// The current wire value (api-docs §6.7.5). See class doc for the rename.
  static const String wireType = 'reaction_update';

  /// The wire value this client no longer expects to see, kept only so a
  /// server that has not rolled the new mapping out yet is still recognised
  /// instead of falling into [WsUnknown]. Handled identically to [wireType] by
  /// the parser.
  static const String legacyWireType = 'chats.message.reaction_updated';
}

/// `member_joined` — a member was added or joined a public chat (api-docs
/// §7.4, revised).
///
/// ⚠️ **No more `user_id`/`role_id`.** Unlike the kick/ban/leave events below,
/// this one needs no identity to stay useful: bumping a chat row's member
/// count (`ChatRealtimeMerge.adjustMemberCount`) and invalidating the roster
/// provider never depended on knowing *who* joined, only that [chatId]'s
/// membership changed.
final class MemberJoined extends WSChatMessageEvent {
  const MemberJoined({
    required super.chatId,
    required super.chat,
    required super.message,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_joined');
}

/// `member_left` — a member left of their own accord (api-docs §7.4, revised).
///
/// ⚠️ **No more `user_id`.** Unlike [MemberJoined], this previously had to
/// distinguish "it was me" (drop the whole chat row) from "it was someone
/// else" (just decrement the count) — a distinction the payload can no longer
/// make. Consumers now treat any `member_left`/[MemberKick]/[MemberBanned] as
/// "membership changed, re-fetch this chat and see if we're still in it"; see
/// `ChatDetailController`/`ChatListController`.
final class MemberLeft extends WSChatMessageEvent {
  const MemberLeft({
    required super.chatId,
    required super.chat,
    required super.message,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_left');
}

/// `member_kick` — someone was removed from the chat (api-docs §7.4, revised).
///
/// ⚠️ **No more `requester_id`/`target_user_id`.** There is no longer any way
/// to tell from this event alone whether *we* are the one kicked. Consumers
/// react by re-fetching the chat (`GET /chats/{chat_id}/`); an access-denied
/// response is now the only reliable signal that we were the target. See
/// `ChatDetailController`'s and `ChatListController`'s handling of this event.
final class MemberKick extends WSChatMessageEvent {
  const MemberKick({
    required super.chatId,
    required super.chat,
    required super.message,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_kick');
}

/// `member_banned` — covers **both** ban and *un*ban, with no way left to tell
/// which (api-docs §7.4, revised).
///
/// ⚠️ **No more `target_user_id`/`ban`.** Previously [ban] distinguished the
/// two directions and `targetUserId` said who; both are gone. A consumer that
/// used to flip a row to "banned" or restore it on `ban: false` can no longer
/// do either from this event — see the same re-fetch-and-check-access strategy
/// as [MemberKick].
final class MemberBanned extends WSChatMessageEvent {
  const MemberBanned({
    required super.chatId,
    required super.chat,
    required super.message,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_banned');
}

/// `chat_created` — delivered to every listed member, not just the creator
/// (api-docs §7.4).
///
/// [chat] is now a full `ChatDTO`, not the old name/type/member-count summary
/// — but `ChatListController` still fetches the chat over REST rather than
/// decoding it directly, because a `ChatDTO` embedded in a broadcast event has
/// no documented guarantee of being personalised per recipient (`me`,
/// `unread_count`, `last_read` are exactly the per-viewer fields a provisional
/// row needs and cannot safely take from a possibly-shared snapshot).
final class ChatCreated extends WSChatMessageEvent {
  const ChatCreated({
    required super.chatId,
    required super.chat,
    required super.message,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('chat_created');
}

/// `chat_updated` — settings changed (api-docs §7.4).
///
/// [chat] is the full updated `ChatDTO`. `ChatRealtimeMerge.applyChatUpdated`
/// still only takes the chat-settings fields from it (`name`, `description`,
/// `is_public`, `admin_only`, `slow_mode_seconds`, `permissions`,
/// `avatar_s3_key`) and keeps the locally-held `me`/`unread_count`/`last_read`
/// — for the same personalisation-is-not-guaranteed reason as [ChatCreated].
///
/// ⚠️ `name`/`description` being `null` is still ambiguous between "cleared"
/// and "this snapshot doesn't distinguish it"; treat this as a hint to trust
/// the decoded [chat] over stale local copies rather than a guaranteed diff.
final class ChatUpdated extends WSChatMessageEvent {
  const ChatUpdated({
    required super.chatId,
    required super.chat,
    required super.message,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('chat_updated');
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
///
/// ⚠️ **Not currently defined in the backend's `WSEventType` enum at all**
/// (api-docs §7.4, revised) — earlier versions of the docs implied it existed;
/// a closer read of the backend found no such member and no publisher for it.
/// Kept here defensively rather than removed: recognising it costs nothing,
/// and if a future backend build does add it, this class means the client
/// already handles it instead of it falling into [WsUnknown]. Do not build a
/// feature that assumes it will arrive.
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
