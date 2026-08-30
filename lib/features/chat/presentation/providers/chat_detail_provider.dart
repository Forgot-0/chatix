import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/models/chat_model.dart';
import 'package:chatix/features/chat/data/models/message_model.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_members_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_realtime_merge.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

const _pageSize = 30;
const _uuid = Uuid();

/// One message the user asked to send that hasn't been acknowledged yet.
///
/// Exists to hold the **idempotency key** alongside the draft. The key is
/// minted once, when the user first presses send, and reused by every retry of
/// that same logical message — that is the whole point of `Idempotency-Key`
/// (api-docs §6.4): within 24 h the backend answers a repeated key with the
/// cached first result instead of creating a duplicate.
///
/// Without this record a retry would mint a fresh key and the "no network →
/// tap send again on reconnect" flow would post the message twice, which is
/// exactly the scenario the header exists to prevent.
class PendingMessage extends Equatable {
  /// Stable across retries — never regenerated.
  final String idempotencyKey;

  final String? content;
  final String? replyToId;
  final List<String> uploadTokens;

  /// Set after an attempt fails, so the row can show why and offer Retry.
  final Failure? failure;

  const PendingMessage({
    required this.idempotencyKey,
    this.content,
    this.replyToId,
    this.uploadTokens = const [],
    this.failure,
  });

  PendingMessage copyWith({Failure? failure, bool clearFailure = false}) {
    return PendingMessage(
      idempotencyKey: idempotencyKey,
      content: content,
      replyToId: replyToId,
      uploadTokens: uploadTokens,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
    idempotencyKey,
    content,
    replyToId,
    uploadTokens,
    failure,
  ];
}

/// State of a single chat screen: the chat itself, the loaded slice of its
/// history and anything still in flight.
///
/// Kept up to date by two sources at once: `GET /chats/{id}/messages/` for the
/// initial page and paging, and the WebSocket subscription for everything that
/// happens afterwards (api-docs §7). The realtime path never *replaces* this
/// state wholesale — it folds individual events in through
/// [ChatRealtimeMerge], so scroll position and pending sends survive.
class ChatDetailState extends Equatable {
  final ChatEntity? chat;

  /// Newest first, matching the order the API returns (api-docs §6.4). The
  /// screen renders a `reverse: true` list, so no re-sorting happens.
  final List<MessageEntity> messages;

  /// Cursor for the next page of *older* messages.
  final int? nextCursor;
  final bool hasNext;
  final bool isLoadingMore;

  /// Sends awaiting a server reply, oldest first.
  final List<PendingMessage> pending;

  /// The message the composer is replying to, if any.
  final MessageEntity? replyTo;

  /// The signed-in user's id, captured when the chat was loaded.
  ///
  /// Required to resolve [me]: this screen's chat comes from
  /// `GET /chats/{id}/`, i.e. a `ChatDetaiDTO`, which carries the full
  /// `members` list and **no `me` field** (api-docs §6.2). Without an id
  /// there is nothing to match a row against, so every permission check
  /// would fail closed and the composer would be permanently disabled.
  final int? myUserId;

  /// Set when a `chat_deleted` event arrives for this chat, or when we are
  /// kicked/banned out of it (api-docs §7.4).
  ///
  /// A flag rather than an immediate navigation: a provider must not push
  /// routes. The screen watches this and shows a terminal "this chat is no
  /// longer available" state, which is also the honest thing to render — every
  /// request against this id will now fail, so silently leaving the stale
  /// history on screen would invite the user to type into a chat that cannot
  /// receive it.
  final bool isGone;

  /// `{messageId: summary}` — reaction chips for the loaded messages (§6.7).
  ///
  /// A separate map rather than a field on [MessageEntity], because
  /// `MessageDTO` carries **no** reactions (§6.4): the summary arrives from its
  /// own `GET .../reactions/` call and is then kept current by
  /// `reaction_update` (§6.7.5). Keying by id keeps the two lifecycles
  /// independent, so re-fetching a message (an edit, a gap replay) never
  /// clobbers a fresher counter.
  ///
  /// A missing key means "not loaded yet" and renders identically to "no
  /// reactions" — an absent chip row.
  final Map<String, MessageReactionsEntity> reactions;

  /// `{readerId: lastReadSeq}` — how far **other** members have read (§7.4).
  ///
  /// ⚠️ **Permanently empty as of the §7.4 payload revision.** `messages_read`
  /// used to carry `reader_id`; it no longer does (see `MessagesRead`'s class
  /// doc), and nothing else in `{chat, message}` says who read up to where.
  /// This map is kept — rather than deleted along with [isReadByPeer] — only
  /// so a future backend fix that restores attribution has somewhere to land
  /// without another round of state-shape changes. Until then, [isReadByPeer]
  /// always returns `false`.
  final Map<int, int> peerReadSeq;

  const ChatDetailState({
    this.chat,
    this.messages = const [],
    this.nextCursor,
    this.hasNext = false,
    this.isLoadingMore = false,
    this.pending = const [],
    this.replyTo,
    this.myUserId,
    this.isGone = false,
    this.reactions = const {},
    this.peerReadSeq = const {},
  });

  bool get canLoadMore => hasNext && nextCursor != null;

  /// Reaction chips for [messageId] — never `null`, so the bubble has exactly
  /// one shape to render whether the summary is absent or merely empty.
  MessageReactionsEntity reactionsFor(String messageId) =>
      reactions[messageId] ?? MessageReactionsEntity.empty(messageId);

  /// Whether [message] has been read by the other party in a **direct** chat.
  ///
  /// ⚠️ **Always `false` as of the §7.4 payload revision** — see
  /// [peerReadSeq]. Kept rather than removed so the call sites (and the
  /// double-check-mark UI reading it) don't need to change again if/when
  /// attribution comes back; today it degrades to a permanent single tick.
  bool isReadByPeer(MessageEntity message) {
    if (chat?.type != ChatType.direct) return false;
    for (final entry in peerReadSeq.entries) {
      if (entry.key == myUserId) continue;
      if (entry.value >= message.seq) return true;
    }
    return false;
  }

  /// The caller's own membership, from whichever field this chat carries it in
  /// — the input to every permission check on the screen.
  ///
  /// ⚠️ Resolved through [ChatEntity.membershipOf] rather than reading
  /// `chat.me` directly: `me` is only populated on a `ChatDTO` (the list,
  /// create and update responses), while `GET /chats/{id}/` returns a
  /// `ChatDetaiDTO` whose membership lives in `members` (api-docs §6.2).
  /// Reading `chat.me` here always yielded `null`, which silently denied
  /// every permission — including `message:send` to a chat's own owner.
  ///
  /// `null` is a legitimate answer for a non-member previewing a public chat,
  /// and must be treated as "deny" (fail-closed) by callers.
  ChatMemberEntity? get me {
    final id = myUserId;
    if (id == null) return chat?.me;
    return chat?.membershipOf(id);
  }

  ChatDetailState copyWith({
    ChatEntity? chat,
    List<MessageEntity>? messages,
    int? nextCursor,
    bool? hasNext,
    bool? isLoadingMore,
    List<PendingMessage>? pending,
    MessageEntity? replyTo,
    bool clearReplyTo = false,
    int? myUserId,
    bool? isGone,
    Map<String, MessageReactionsEntity>? reactions,
    Map<int, int>? peerReadSeq,
  }) {
    return ChatDetailState(
      chat: chat ?? this.chat,
      messages: messages ?? this.messages,
      myUserId: myUserId ?? this.myUserId,
      // Replaced wholesale, including back to null when history is exhausted:
      // a stale cursor would re-read the same window forever.
      nextCursor: nextCursor,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pending: pending ?? this.pending,
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
      isGone: isGone ?? this.isGone,
      reactions: reactions ?? this.reactions,
      peerReadSeq: peerReadSeq ?? this.peerReadSeq,
    );
  }

  @override
  List<Object?> get props => [
    chat,
    messages,
    nextCursor,
    hasNext,
    isLoadingMore,
    pending,
    replyTo,
    myUserId,
    isGone,
    reactions,
    peerReadSeq,
  ];
}

/// Drives `ChatDetailScreen` for one `chatId`.
///
/// Owns both halves of the protocol for this chat: the REST reads (§6.4) and
/// the live subscription (§7). The socket itself is *not* owned here — it is an
/// app-wide singleton (see `chat_socket_provider.dart`); this controller only
/// subscribes to one chat for as long as its screen is mounted.
class ChatDetailController extends AsyncNotifier<ChatDetailState> {
  ChatDetailController(this._chatId);

  /// The chat this controller is scoped to. Riverpod 3's manual `family` API
  /// hands the argument to the constructor (there is no inherited `arg`), so
  /// the provider below forwards it.
  final String _chatId;

  StreamSubscription<WSEvent>? _eventSubscription;

  /// Message ids whose reaction summary is being fetched right now.
  ///
  /// Guards against a duplicate in-flight `GET .../reactions/`: scrolling can
  /// re-enter [loadReactionsFor] with the same ids before the first batch
  /// returns, and a `reaction_update` can arrive while that first batch is
  /// still in flight — without this, every visible message could be requested
  /// repeatedly.
  final Set<String> _reactionFetches = <String>{};

  /// Set while a `member_left`/`member_kick`/`member_banned` re-fetch (see
  /// [_refreshMembershipOrLeave]) is in flight, so a burst of the same event
  /// (plausible in an active group) doesn't queue up duplicate requests.
  bool _membershipRefreshInFlight = false;

  @override
  Future<ChatDetailState> build() async {
    // Registered before the first await: `onDispose` callbacks added after an
    // async gap are silently dropped if the provider is disposed during the
    // gap, which is exactly the "user opened and immediately backed out" case
    // — and would leak the subscription for the rest of the session.
    ref.onDispose(_teardown);

    final loaded = await _load();

    // Subscribe only after history is loaded, so `lastSeq` is the real
    // high-water mark. Subscribing first would either send no cursor (and get
    // no gap replay) or a stale one.
    _attachRealtime(loaded);

    return loaded;
  }

  /// Opens the live subscription for this chat and starts folding events in.
  ///
  /// `subscribe` carries the newest `seq` we hold, so the server answers with a
  /// `ws.history` batch covering anything that happened between the REST read
  /// and the subscription taking effect (§7.3). That window is small but real,
  /// and without the cursor those messages would be lost until the next manual
  /// refresh.
  void _attachRealtime(ChatDetailState loaded) {
    final socket = ref.read(chatSocketServiceProvider);

    socket.subscribe(
      _chatId,
      lastSeq: ChatRealtimeMerge.highestSeq(loaded.messages),
    );

    // Filtering happens here rather than in the service: the socket is shared
    // by every chat, and each controller cares only about its own.
    _eventSubscription = socket.events.listen(
      _onEvent,
      // A malformed frame must not cancel this subscription — that would end
      // live updates for this chat with no visible symptom. The parser already
      // degrades bad frames to `WsUnknown`, so reaching here is unexpected.
      onError: (Object error, StackTrace stackTrace) {
        Logger.error(
          'ChatDetail($_chatId): event stream error',
          error,
          stackTrace,
        );
      },
      cancelOnError: false,
    );
  }

  void _teardown() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    // Tell the server to stop sending us this chat's events. Safe even if the
    // socket is down — the service forgets the subscription either way, so a
    // later reconnect won't resurrect it.
    ref.read(chatSocketServiceProvider).unsubscribe(_chatId);
  }

  /// Folds one event into this chat's state (§7.4/§7.5).
  ///
  /// The `switch` is exhaustive over the sealed [WSEvent] hierarchy, so a new
  /// event type added to the protocol breaks this build until it is handled
  /// here — which is the point: silently ignoring a new event is how a chat
  /// quietly stops updating.
  Future<void> _onEvent(WSEvent event) async {
    // Events for other chats belong to other controllers (and to the list).
    if (event is WSDomainEvent && event.chatId != _chatId) return;

    switch (event) {
      case NewMessage():
        await _onNewMessage(event);

      case MessageEdited():
        // [message] is now the full post-edit `MessageDTO` (api-docs §7.4,
        // revised) — decode and replace directly, no re-fetch needed.
        _upsertDecodedMessage(event);

      case MessageDeleted():
        _mutate(
          (s) => s.copyWith(
            messages: ChatRealtimeMerge.applyMessageDeleted(
              s.messages,
              event.messageId ?? '',
              asTombstone: true,
            ),
            // Drop a reply draft pointing at a message that no longer exists,
            // otherwise sending it would fail with a dangling `reply_to_id`.
            clearReplyTo: s.replyTo?.id == event.messageId,
            nextCursor: s.nextCursor,
          ),
        );

      case WsHistory():
        if (event.chatId != _chatId) return;
        _onHistory(event);

      case MessagesRead():
        // ⚠️ Inert. The §7.4 payload revision dropped `reader_id` with no
        // replacement (see `MessagesRead`'s class doc) — there is no longer
        // any way to tell "I read this on another device" from "a peer read
        // it", so `ChatDetailState.peerReadSeq` can no longer be safely
        // updated from this event. Our own read cursor is unaffected: it is
        // driven entirely by our own actions (`_markReadUpTo`), never by this
        // WS echo.
        break;

      case ReactionUpdated():
        await _onReactionUpdated(event);

      case ChatUpdated():
        _mutate((s) {
          final chat = s.chat;
          final updated = _decodeChat(event.chat);
          if (chat == null || updated == null) return s;
          return s.copyWith(
            chat: ChatRealtimeMerge.applyChatUpdated(chat, updated),
            nextCursor: s.nextCursor,
          );
        });

      case ChatDeleted():
        _mutate((s) => s.copyWith(isGone: true, nextCursor: s.nextCursor));

      case MemberKick():
      case MemberBanned():
      case MemberLeft():
        // §7.4's payload revision dropped `target_user_id`/`requester_id`/
        // `ban` (kick, banned) and `user_id` (left) with no replacement — see
        // `WSChatMessageEvent`'s class doc. There is no longer any local
        // signal for "was it me". The only reliable way left to find out is
        // to ask the server: re-fetch this chat, and treat an access-denied
        // response as "yes, it was me".
        await _refreshMembershipOrLeave();

      case MemberJoined():
        // Unaffected by the payload revision (`ChatRealtimeMerge.
        // adjustMemberCount`'s doc) — no identity was ever needed here.
        // The roster lives in its own provider (`chatMembersProvider`) with
        // its own pagination, so it is refreshed rather than patched here.
        _invalidateMembers();

      case AttachmentSuccess():
        // Handled by `confirmedAttachmentTokensProvider`, which watches the
        // same stream. Duplicating it here would fight that provider for
        // ownership of the composer's spinner state.
        break;

      // ── Not this controller's concern ──
      case ChatCreated():
        // A chat we are already inside cannot be created; if it somehow
        // arrives, the list provider is the right consumer.
        break;

      case WsReady():
        // Re-subscription is the service's job (`_resumeSubscriptions` sends a
        // `resume` with our cursor). Nothing to do here — and calling
        // `subscribe` would race that.
        break;

      case WsSubscribed():
      case WsUnsubscribed():
      case WsPing():
      case WsPong():
      case WsErrorBadCommand():
      case WsErrorNotChatMember():
      case WsAuthInvalid():
      case WsUnimplementedEvent():
      case WsUnknown():
        break;
    }
  }

  /// `new_message` (api-docs §7.4, revised).
  ///
  /// The old §7.5-step-3 "should we fetch?" branch is gone along with the
  /// payload shape it was built for — [event.message] is already a complete
  /// `MessageDTO` (see [NewMessage]'s class doc), so this just decodes and
  /// upserts it, own message or not. `upsertMessage`'s id-based replace makes
  /// this safe even when our own optimistic insert from `POST /messages/`
  /// beat the event here.
  Future<void> _onNewMessage(NewMessage event) async {
    final message = _upsertDecodedMessage(event);
    if (message == null) return;

    // The user is looking at this chat, so an arriving message is read on
    // arrival. Fire-and-forget, exactly like the send path.
    await _markReadUpTo(message.seq);
  }

  /// Decodes [event.message] and folds it into the message list, replacing
  /// any existing copy with the same id (`ChatRealtimeMerge.upsertMessage`).
  ///
  /// Returns the decoded entity so callers that need one more thing from it
  /// (`_onNewMessage` wants [MessageEntity.seq] for the read cursor) don't
  /// have to decode a second time; `null` when [event.message] itself could
  /// not be decoded — a malformed frame then costs this one update, not the
  /// whole chat.
  MessageEntity? _upsertDecodedMessage(WSChatMessageEvent event) {
    final message = _decodeMessage(event.message);
    if (message == null) return null;

    _mutate(
      (s) => s.copyWith(
        messages: ChatRealtimeMerge.upsertMessage(s.messages, message),
        nextCursor: s.nextCursor,
      ),
    );
    return message;
  }

  MessageEntity? _decodeMessage(Map<String, dynamic> raw) {
    try {
      return MessageModel.fromJson(raw).toEntity();
    } catch (error) {
      // One malformed payload must not take the whole event down with it —
      // same posture as `_onHistory`'s per-row try/catch below.
      Logger.warning('ChatDetail($_chatId): bad message payload: $error');
      return null;
    }
  }

  ChatEntity? _decodeChat(Map<String, dynamic> raw) {
    try {
      return ChatModel.fromJson(raw).toEntity();
    } catch (error) {
      Logger.warning('ChatDetail($_chatId): bad chat payload: $error');
      return null;
    }
  }

  /// Folds a `ws.history` gap replay in (§7.4).
  ///
  /// These frames carry **full `MessageDTO`s** — the only place in the protocol
  /// where message content arrives over the socket — so they need no follow-up
  /// requests at all. Decoded with the same `MessageModel.fromJson` used for
  /// REST, since it is the same DTO.
  ///
  /// `has_more: true` means the gap was larger than one batch. Rather than
  /// paging the socket, the messages received are merged and the user can pull
  /// to refresh; the alternative (a `subscribe` loop chasing `next_last_seq`)
  /// risks hammering the connection on a long absence.
  void _onHistory(WsHistory event) {
    if (event.messages.isEmpty) return;

    final decoded = <MessageEntity>[];
    for (final raw in event.messages) {
      try {
        decoded.add(MessageModel.fromJson(raw).toEntity());
      } catch (error) {
        // One malformed row must not discard the rest of the batch.
        Logger.warning('ChatDetail($_chatId): bad ws.history message: $error');
      }
    }
    if (decoded.isEmpty) return;

    _mutate((s) {
      var messages = s.messages;
      for (final message in decoded) {
        messages = ChatRealtimeMerge.upsertMessage(messages, message);
      }
      return s.copyWith(messages: messages, nextCursor: s.nextCursor);
    });

    // The whole replayed batch is on screen, so it is read.
    final newest = ChatRealtimeMerge.highestSeq(decoded);
    if (newest != null) _markReadUpTo(newest);
  }

  bool _hasMessage(String messageId) =>
      state.value?.messages.any((m) => m.id == messageId) ?? false;

  void _invalidateMembers() {
    ref.invalidate(chatMembersProvider(_chatId));
  }

  /// The shared reaction to `member_left`/`member_kick`/`member_banned`
  /// (api-docs §7.4, revised).
  ///
  /// None of the three still names a target user (see their class docs), so
  /// there is no longer a local way to tell "it was me" from "it was someone
  /// else". This asks the server instead: re-`GET` the chat, and read an
  /// access-denied response as the only remaining reliable signal that we
  /// were the one removed. Any other outcome means membership merely
  /// *changed* while we're still in it, so the fresh chat (accurate
  /// `member_count`, permissions, etc.) replaces the stale one and the roster
  /// provider is invalidated alongside it.
  Future<void> _refreshMembershipOrLeave() async {
    if (_membershipRefreshInFlight) return;
    _membershipRefreshInFlight = true;

    try {
      final result = await ref.read(getChatUseCaseProvider).execute(_chatId);

      result.match((failure) {
        if (_isAccessDenied(failure)) {
          _mutate((s) => s.copyWith(isGone: true, nextCursor: s.nextCursor));
        } else {
          // Any other failure (network, 5xx) leaves the screen as-is rather
          // than guessing — the next membership event, or re-entering the
          // chat, will try again.
          Logger.warning(
            'ChatDetail($_chatId): membership refresh failed '
            '(${failure.message})',
          );
        }
      }, (chat) => _mutate((s) => s.copyWith(chat: chat, nextCursor: s.nextCursor)));
    } finally {
      _membershipRefreshInFlight = false;
    }

    // Refreshed regardless of the outcome above (short of the request itself
    // failing to run): even when we're still a member, who is on the roster
    // may have changed, and when we're not, an already-open members sheet
    // should stop showing stale rows.
    _invalidateMembers();
  }

  /// Whether [failure] means "you are not, or no longer, in this chat" —
  /// the codes api-docs §6.2/§6.6 document for a chat the caller cannot see.
  bool _isAccessDenied(Failure failure) {
    if (failure is! ApiFailure) return false;
    return const {
      'NOT_CHAT_MEMBER',
      'CHAT_ACCESS_DENIED',
      'NOT_FOUND_CHAT',
    }.contains(failure.code);
  }

  /// Applies [transform] to the current data state, if there is one.
  ///
  /// Every realtime mutation goes through this. It exists to keep two rules in
  /// one place: never write while the provider is loading or errored (which
  /// would resurrect a dead screen), and never touch `state` after disposal —
  /// Riverpod 3 throws on that, and an event can arrive in the same microtask
  /// as the dispose.
  // ─────────────────────── Reactions (§6.7) ────────────────────────

  /// Reacts to `reaction_update` (api-docs §6.7.5, revised).
  ///
  /// ⚠️ The payload no longer carries `emoji`/`count`/`changed_by` — only the
  /// generic `chat`/`message` pair, and `MessageDTO` has no reactions field at
  /// all (§6.4; see [ReactionUpdated]'s class doc on the §6.7.5 comment that
  /// briefly suggested otherwise). There is nothing left to apply locally, so
  /// the only correct reaction is to treat this as "the summary we hold for
  /// this message is stale" and re-fetch it — unlike [loadReactionsFor], which
  /// skips messages already cached, this refetches unconditionally.
  ///
  /// Ignored for a message outside the loaded window, same as before: the
  /// summary is fetched when that message scrolls in, not stored ahead of it.
  Future<void> _onReactionUpdated(ReactionUpdated event) async {
    final messageId = event.messageId;
    if (messageId == null || !_hasMessage(messageId)) return;
    if (!_reactionFetches.add(messageId)) return;

    try {
      final result = await ref
          .read(getReactionsUseCaseProvider)
          .execute(_chatId, messageId);

      result.match(
        (failure) => Logger.warning(
          'ChatDetail($_chatId): reactions refresh for $messageId '
          '(${failure.message})',
        ),
        (reactions) => _mutate(
          (s) => s.copyWith(
            reactions: {...s.reactions, messageId: reactions},
            nextCursor: s.nextCursor,
          ),
        ),
      );
    } finally {
      _reactionFetches.remove(messageId);
    }
  }

  /// Loads reaction summaries for messages that don't have one yet (§6.7.1).
  ///
  /// Necessary because `MessageDTO` has no reactions field (§6.4): without this
  /// a freshly opened chat shows no chips at all until somebody reacts while
  /// the screen happens to be open.
  ///
  /// ⚠️ One request per message — the endpoint is per-message and §6.7 defines
  /// no batch form. Only ids missing from the map are fetched, so paging older
  /// history costs one round-trip per newly revealed message and re-entering a
  /// chat costs nothing for what is already known.
  Future<void> loadReactionsFor(Iterable<String> messageIds) async {
    final current = state.value;
    if (current == null) return;

    final missing = messageIds
        .toSet()
        .where((id) => !current.reactions.containsKey(id))
        .where(_reactionFetches.add)
        .toList();
    if (missing.isEmpty) return;

    final useCase = ref.read(getReactionsUseCaseProvider);

    try {
      final loaded = <String, MessageReactionsEntity>{};
      for (final messageId in missing) {
        final result = await useCase.execute(_chatId, messageId);
        result.match(
          // Never surfaced: a missing chip row is a cosmetic loss, an error
          // banner over a readable conversation is not.
          (failure) => Logger.warning(
            'ChatDetail($_chatId): reactions for $messageId '
            '(${failure.message})',
          ),
          (reactions) => loaded[messageId] = reactions,
        );
      }
      if (loaded.isEmpty) return;

      _mutate(
        (s) => s.copyWith(
          // A WS frame that landed while this was in flight is newer than the
          // response, so whatever is already in the map wins.
          reactions: {...loaded, ...s.reactions},
          nextCursor: s.nextCursor,
        ),
      );
    } finally {
      _reactionFetches.removeAll(missing);
    }
  }

  /// Sets, replaces or clears the current user's reaction on a message.
  ///
  /// Single-choice (§6.7.2): tapping the emoji we already have removes it,
  /// tapping a different one *replaces* — no explicit DELETE for the old emoji
  /// is needed, and the backend answers a replacement with **two**
  /// `reaction_update` frames.
  ///
  /// The summary is updated optimistically so the chip reacts to the tap
  /// immediately rather than after a socket round-trip; a failed request rolls
  /// the pre-tap snapshot back.
  Future<void> toggleReaction(String messageId, String emoji) async {
    final current = state.value;
    if (current == null) return;

    final before = current.reactionsFor(messageId);
    final isRemoval = before.myEmoji == emoji;

    _mutate(
      (s) => s.copyWith(
        reactions: {
          ...s.reactions,
          messageId: _applyMyReaction(
            s.reactionsFor(messageId),
            emoji: isRemoval ? null : emoji,
          ),
        },
        nextCursor: s.nextCursor,
      ),
    );

    final result = isRemoval
        ? await ref
              .read(removeReactionUseCaseProvider)
              .execute(_chatId, messageId, emoji)
        : await ref
              .read(setReactionUseCaseProvider)
              .execute(_chatId, messageId, emoji);

    result.match((failure) {
      Logger.warning(
        'ChatDetail($_chatId): reaction $emoji on $messageId failed '
        '(${failure.message})',
      );
      // Restore the pre-tap snapshot rather than re-deriving it: the request
      // never took effect, so the truth is exactly what we had before.
      _mutate(
        (s) => s.copyWith(
          reactions: {...s.reactions, messageId: before},
          nextCursor: s.nextCursor,
        ),
      );
    }, (_) {});
  }

  /// Applies "my reaction is now [emoji]" (or none) to a summary locally.
  ///
  /// Enforces the single-choice invariant client-side: the previous chip loses
  /// its count and highlight in the same step the new one gains them, which is
  /// what stops a replacement from briefly showing two highlighted chips while
  /// the two WS frames are still in flight.
  MessageReactionsEntity _applyMyReaction(
    MessageReactionsEntity summary, {
    required String? emoji,
  }) {
    final next = <ReactionSummaryEntity>[];
    var found = false;

    for (final chip in summary.summaries) {
      if (chip.emoji == emoji) {
        found = true;
        next.add(
          chip.copyWith(
            // Guard against double-counting a chip that is already ours.
            count: chip.reactedByMe ? chip.count : chip.count + 1,
            reactedByMe: true,
          ),
        );
      } else if (chip.reactedByMe) {
        // The emoji we are moving away from; drop it if we were its only fan.
        if (chip.count > 1) {
          next.add(chip.copyWith(count: chip.count - 1, reactedByMe: false));
        }
      } else {
        next.add(chip);
      }
    }

    if (emoji != null && !found) {
      next.add(
        ReactionSummaryEntity(emoji: emoji, count: 1, reactedByMe: true),
      );
    }

    return summary.copyWith(summaries: next);
  }

  void _mutate(ChatDetailState Function(ChatDetailState state) transform) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(transform(current));
  }

  Future<void> refresh() async {
    // Keeps the current frame on screen while re-fetching (no spinner flash)
    // — the list is long-lived and the user is usually reading it.
    final previous = state.value;
    final next = await AsyncValue.guard(_load);
    state = next.hasError && previous != null
        ? AsyncValue.data(previous)
        : next;

    // Re-point the socket's cursor at what we now hold. A refresh can pull in
    // messages the subscription never delivered (it was down, or the user
    // pulled to refresh mid-outage), and leaving the old cursor in place would
    // make the next `resume` replay history already on screen.
    //
    // `subscribe` is idempotent server-side and the service takes the *max* of
    // the two cursors, so this cannot rewind anything.
    final messages = state.value?.messages;
    if (messages != null && messages.isNotEmpty) {
      ref
          .read(chatSocketServiceProvider)
          .subscribe(_chatId, lastSeq: ChatRealtimeMerge.highestSeq(messages));
    }
  }

  /// Appends the next page of older history.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.canLoadMore || current.isLoadingMore) {
      return;
    }

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final result = await ref
        .read(getMessagesUseCaseProvider)
        .executeOlder(
          _chatId,
          MessagesPage(
            messages: const [],
            nextCursor: current.nextCursor,
            hasNext: current.hasNext,
          ),
          limit: _pageSize,
        );

    state = result.fold(
      // Drop the spinner but keep the history already read — losing a
      // scrolled-through conversation because one page failed is far worse
      // than the missing page.
      (_) => AsyncValue.data(
        current.copyWith(isLoadingMore: false, nextCursor: current.nextCursor),
      ),
      (page) => AsyncValue.data(
        current.copyWith(
          messages: [...current.messages, ...page.messages],
          nextCursor: page.nextCursor,
          hasNext: page.hasNext,
          isLoadingMore: false,
        ),
      ),
    );
  }

  void setReplyTo(MessageEntity? message) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      message == null
          ? current.copyWith(clearReplyTo: true, nextCursor: current.nextCursor)
          : current.copyWith(replyTo: message, nextCursor: current.nextCursor),
    );
  }

  /// Sends [content] (and/or [uploadTokens]) as a new message.
  ///
  /// Mints one idempotency key here and hands it to [_attemptSend]; [retry]
  /// reuses the very same key, which is what makes a retry safe.
  Future<void> sendMessage({
    String? content,
    List<String> uploadTokens = const [],
  }) async {
    final current = state.value;
    if (current == null) return;

    final pending = PendingMessage(
      idempotencyKey: _uuid.v4(),
      content: content,
      replyToId: current.replyTo?.id,
      uploadTokens: uploadTokens,
    );

    state = AsyncValue.data(
      current.copyWith(
        pending: [...current.pending, pending],
        // The composer's reply banner clears immediately — the reply target is
        // already captured in `pending`.
        clearReplyTo: true,
        nextCursor: current.nextCursor,
      ),
    );

    await _attemptSend(pending);
  }

  /// Re-sends a failed message **with its original key**, so if the first
  /// attempt actually reached the server the backend returns that same
  /// message instead of creating a second one (api-docs §6.4).
  Future<void> retry(PendingMessage message) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(
        pending: [
          for (final p in current.pending)
            if (p.idempotencyKey == message.idempotencyKey)
              p.copyWith(clearFailure: true)
            else
              p,
        ],
        nextCursor: current.nextCursor,
      ),
    );

    await _attemptSend(message);
  }

  /// Abandons a failed send.
  void discard(PendingMessage message) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        pending: current.pending
            .where((p) => p.idempotencyKey != message.idempotencyKey)
            .toList(),
        nextCursor: current.nextCursor,
      ),
    );
  }

  Future<void> _attemptSend(PendingMessage pending) async {
    final result = await ref
        .read(sendMessageUseCaseProvider)
        .execute(
          _chatId,
          content: pending.content,
          replyToId: pending.replyToId,
          uploadTokens: pending.uploadTokens.isEmpty
              ? null
              : pending.uploadTokens,
          idempotencyKey: pending.idempotencyKey,
        );

    final current = state.value;
    if (current == null) return;

    state = result.fold(
      (failure) => AsyncValue.data(
        current.copyWith(
          pending: [
            for (final p in current.pending)
              if (p.idempotencyKey == pending.idempotencyKey)
                p.copyWith(failure: failure)
              else
                p,
          ],
          nextCursor: current.nextCursor,
        ),
      ),
      (message) {
        // The server's message replaces the pending row. Merged through
        // `upsertMessage` rather than prepended, which handles both hazards in
        // one place: the idempotent-replay case (a replayed key returns a
        // message we may already be displaying) and a racing `new_message`
        // event for this very send that got fetched first. Keyed on `id`, so
        // either way there is exactly one bubble.
        return AsyncValue.data(
          current.copyWith(
            messages: ChatRealtimeMerge.upsertMessage(
              current.messages,
              message,
            ),
            pending: current.pending
                .where((p) => p.idempotencyKey != pending.idempotencyKey)
                .toList(),
            nextCursor: current.nextCursor,
          ),
        );
      },
    );

    final sent = result.getRight().toNullable();

    // Keep the socket's cursor level with our own send. Without this, our
    // message's `seq` is only learned from the (ignored) `new_message` echo, and
    // a reconnect immediately after sending would ask the server to replay it.
    if (sent != null) {
      ref.read(chatSocketServiceProvider).subscribe(_chatId, lastSeq: sent.seq);
    }

    await _markReadUpTo(sent?.seq);
  }

  /// Marks the chat read up to [seq] (api-docs §6.4). Fire-and-forget: a
  /// failed read receipt must never surface as a send error.
  Future<void> _markReadUpTo(int? seq) async {
    if (seq == null) return;
    await ref.read(markReadUseCaseProvider).execute(_chatId, seq);
  }

  /// Deletes one message and **returns** the failure message instead of
  /// throwing, for callers that must keep going after a failure.
  ///
  /// Exists because [deleteMessage] rethrows so a single-message UI can show
  /// an error dialog — which is exactly wrong for a bulk loop, where one
  /// refusal (a message too old, a rate limit) must not abort the remaining
  /// deletions or leave them silently unattempted.
  ///
  /// Returns `null` on success.
  Future<String?> deleteMessageReportingFailure(String messageId) async {
    try {
      await deleteMessage(messageId);
      return null;
    } on Failure catch (failure) {
      return failure.message;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final result = await ref
        .read(deleteMessageUseCaseProvider)
        .execute(_chatId, messageId);
    final current = state.value;
    if (current == null) return;
    result.match((failure) => throw failure, (_) {
      state = AsyncValue.data(
        current.copyWith(
          messages: current.messages.where((m) => m.id != messageId).toList(),
          nextCursor: current.nextCursor,
        ),
      );
    });
  }

  Future<void> editMessage(String messageId, String content) async {
    final result = await ref
        .read(editMessageUseCaseProvider)
        .execute(_chatId, messageId, content);
    final current = state.value;
    if (current == null) return;
    result.match((failure) => throw failure, (updated) {
      state = AsyncValue.data(
        current.copyWith(
          messages: [
            for (final m in current.messages)
              if (m.id == updated.id) updated else m,
          ],
          nextCursor: current.nextCursor,
        ),
      );
    });
  }

  Future<ChatDetailState> _load() async {
    // Who "me" is, for the §9.1 permission checks below. Watched (not read)
    // so signing in/out rebuilds the chat with the right membership instead
    // of leaving a stale one on screen.
    final myUserId = ref.watch(authProvider).value?.id;

    // `GET /chats/{id}/` and the first page of history are independent
    // requests — issued together so opening a chat costs one round-trip of
    // latency instead of two.
    //
    // Typed explicitly rather than through `Future.wait`: a `Future.wait` of
    // two differently-typed `Either`s degrades to `List<Object?>` and forces
    // `as dynamic` casts that move type errors to runtime.
    final chatFuture = ref.read(getChatUseCaseProvider).execute(_chatId);
    final messagesFuture = ref
        .read(getMessagesUseCaseProvider)
        .execute(_chatId, limit: _pageSize);

    final chat = (await chatFuture).getOrElse((failure) => throw failure);
    final page = (await messagesFuture).getOrElse((failure) => throw failure);

    // Opening a chat with unread messages is itself a read event; the newest
    // loaded `seq` is the high-water mark (api-docs §6.4).
    if (page.messages.isNotEmpty) {
      await _markReadUpTo(page.messages.first.seq);
    }

    return ChatDetailState(
      chat: chat,
      messages: page.messages,
      nextCursor: page.nextCursor,
      hasNext: page.hasNext,
      myUserId: myUserId,
    );
  }
}

/// One controller per open chat.
///
/// ⚠️ **`isAutoDispose: true` is load-bearing, not a memory optimisation.**
/// Riverpod 3 defaults `isAutoDispose` to `false` for hand-written providers
/// (only code-generated ones default to on), so without this flag the
/// controller — and with it the event subscription — would live for the rest of
/// the session after the screen closed. Three concrete consequences:
///
/// * `_teardown` would never run, so `unsubscribe` would never be sent and the
///   server would keep pushing every message of every chat the user had *ever*
///   opened (§7.3).
/// * Those chats would stay in the service's subscription list and so keep
///   competing for the 20 slots a `resume` may carry (§7.3), eventually
///   crowding out the chat actually on screen.
/// * Each abandoned controller would go on fetching message bodies for events
///   nobody is rendering.
final chatDetailProvider =
    AsyncNotifierProvider.family<ChatDetailController, ChatDetailState, String>(
      ChatDetailController.new,
      isAutoDispose: true,
    );
