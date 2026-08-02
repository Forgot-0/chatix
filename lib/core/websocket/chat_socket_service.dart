import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/storage/secure_storage_service.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/core/websocket/ws_event_parser.dart';

/// Connection state of the chat socket, for the UI's status indicator.
///
/// [reconnecting] is deliberately distinct from [connecting]: the first
/// connection of a session is invisible plumbing (the screen is showing its
/// own loading state anyway), while a *re*connect means the user was live and
/// no longer is — that is worth a banner. Collapsing them would either flash a
/// "reconnecting" banner on every cold start or hide a real outage.
enum ChatSocketStatus {
  /// No socket, and none wanted — before login or after [ChatSocketService.disconnect].
  disconnected,

  /// First connection attempt of this session; handshake in flight.
  connecting,

  /// `ws.ready` received. The only state in which commands actually reach the
  /// server.
  ready,

  /// Lost an established connection; backoff timer running. Live updates are
  /// paused but the cursor map is intact, so nothing will be missed once
  /// `resume` lands.
  reconnecting,
}

/// Single, app-wide client for the chat WebSocket protocol (api-docs §7).
///
/// ## Why this lives in `core/`, not `features/chat/data/`
///
/// The connection is a **process-level singleton**, not a per-screen resource.
/// The server allows only **2 concurrent connections per user** and evicts the
/// oldest with close code **1012** (§7.2), so a socket created per chat screen
/// would evict itself as soon as the user opened a third chat. It also has to
/// keep receiving `chat_created` / `new_message` for chats that are *not* on
/// screen — that is what drives unread badges — so its lifetime is the session's,
/// not any widget's. Placing it under `features/chat/data` would invite exactly
/// the per-screen instantiation the protocol cannot survive.
///
/// The trade-off accepted in return: this file must not import `features/*`, so
/// message data crosses the boundary as raw JSON maps ([WsHistory.messages]) and
/// enums as wire strings. The chat feature decodes them with the same
/// `MessageModel.fromJson` it uses for REST.
///
/// ## What it owns
///
/// * one [WebSocketChannel] and its lifecycle;
/// * the heartbeat contract (§7.2) — answering `ws.ping`, and proactively
///   pinging so a quiet client is never closed with 1001;
/// * reconnection with exponential backoff, and the close-code policy (§7.5);
/// * the `{chatId: lastSeq}` cursor map that makes a reconnect lossless, and
///   the ≤20 clamp that keeps `resume` from killing the connection (§7.3).
///
/// ## What it does NOT own
///
/// Message state. Domain events are forwarded verbatim to [events]; deciding
/// what to fetch and what to merge is the controllers' job (§7.5 step 3). This
/// service holds no messages, so it cannot go stale.
class ChatSocketService {
  ChatSocketService({
    required SecureStorageService secureStorage,
    this.deviceId,
    Uri Function(Uri uri)? channelFactoryUri,
    WebSocketChannel Function(Uri uri)? channelFactory,
  })  : _secureStorage = secureStorage,
        _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final SecureStorageService _secureStorage;

  /// Optional `device_id` query parameter (§7.1). When omitted the backend
  /// derives one from the JWT or falls back to `"unknown"`, so this is a
  /// nice-to-have for session lists, never a requirement.
  final String? deviceId;

  /// Injection seam for tests: swaps in a fake channel without a real server.
  /// `WebSocketChannel.connect` in production, which picks the right transport
  /// (`dart:io` / `dart:html`) per platform on its own.
  final WebSocketChannel Function(Uri uri) _channelFactory;

  // ───────────────────────────── Connection state ─────────────────────────────

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;

  final StreamController<WSEvent> _eventController =
      StreamController<WSEvent>.broadcast();

  final StreamController<ChatSocketStatus> _statusController =
      StreamController<ChatSocketStatus>.broadcast();

  ChatSocketStatus _status = ChatSocketStatus.disconnected;

  /// `true` once [connect] has been called and until [disconnect] is; the
  /// difference between "the socket dropped" (reconnect) and "we closed it"
  /// (stay closed). Without this flag a deliberate sign-out would immediately
  /// reconnect itself.
  bool _intentionallyClosed = true;

  /// Guards against two overlapping handshakes — e.g. a backoff timer firing
  /// just as the app returns to the foreground and calls [connect] again. Two
  /// live sockets would burn the user's 2-connection budget on one device.
  bool _connecting = false;

  // ───────────────────────────── Subscriptions ─────────────────────────────

  /// Chats the UI currently cares about, in **least-recently-used order**
  /// (most recent last).
  ///
  /// Insertion order is load-bearing: it is what "20 freshest" means when
  /// [resume] has to clamp. A plain `Set` would make that choice arbitrary,
  /// so re-subscribing an existing chat deliberately moves it to the end.
  final List<String> _subscribedChatIds = [];

  /// `{chatId: lastSeq}` — the newest `seq` this client has *seen* per chat.
  ///
  /// The single source of truth for gap recovery: fed to `subscribe.last_seq`
  /// and `resume.cursors` so the server can replay exactly what was missed
  /// (§7.2, §10.5). Updated from every seq-bearing event, so it stays correct
  /// even for chats that are subscribed but not on screen.
  final Map<String, int> _cursors = {};

  // ───────────────────────────── Heartbeat ─────────────────────────────

  /// From `ws.ready.payload.heartbeat_interval` (§7.4). Server default 30 s;
  /// this initial value is only a placeholder until the first `ws.ready`.
  int _heartbeatInterval = 30;

  /// From `ws.ready.payload.heartbeat_timeout` — how long we may stay silent
  /// before the server closes us with 1001. **Never hard-coded**: the server
  /// owns this number and can retune it.
  int _heartbeatTimeout = 75;

  Timer? _heartbeatTimer;

  /// When we last sent *anything*. Any client frame resets the server's timer
  /// (§7.2), so this — not "when we last ponged" — is what decides whether a
  /// proactive ping is needed.
  DateTime? _lastSentAt;

  // ───────────────────────────── Reconnection ─────────────────────────────

  Timer? _reconnectTimer;

  /// Number of consecutive failed attempts; drives the backoff curve and is
  /// reset by every `ws.ready`.
  int _reconnectAttempt = 0;

  static const List<Duration> _backoffSchedule = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  /// Jitter ceiling. Without it, every client evicted by one gateway restart
  /// reconnects in lockstep and the thundering herd knocks it over again.
  static const int _maxJitterMs = 400;

  final Random _random = Random();

  /// `resume.cursors` hard cap (§7.3).
  ///
  /// ⚠️ Exceeding it does **not** produce a polite `ws.error`: the handler
  /// raises an unwrapped `MAX_LIMIT_CURSOR` that can drop the connection —
  /// which would then reconnect and resend the same oversized frame. Hence the
  /// clamp in [resume] and [_resumeSubscriptions].
  static const int maxResumeCursors = 20;

  // ───────────────────────────── Public API ─────────────────────────────

  /// All incoming events, plus the synthetic [WsAuthInvalid].
  ///
  /// Broadcast and never closed while the app lives, so late subscribers (a
  /// chat screen opened an hour after login) attach without restarting
  /// anything. Consumers filter by `chatId` themselves.
  Stream<WSEvent> get events => _eventController.stream;

  /// Connection state for the UI indicator. Broadcast; read [status] for the
  /// current value, since a fresh listener gets no replay.
  Stream<ChatSocketStatus> get statusStream => _statusController.stream;

  ChatSocketStatus get status => _status;

  /// `true` when the socket was closed with **1008** — the access token is
  /// missing or rejected (§7.1).
  ///
  /// A [ValueListenable] as well as a [WsAuthInvalid] event because the two
  /// have different audiences: a widget can `ValueListenableBuilder` on this
  /// without touching the event stream, and — critically — it *latches*, so an
  /// app-level listener that attaches after the failure still sees it, whereas
  /// the one-shot event would already be gone.
  ///
  /// Cleared by the next successful [connect].
  ValueListenable<bool> get isTokenInvalid => _isTokenInvalid;
  final ValueNotifier<bool> _isTokenInvalid = ValueNotifier<bool>(false);

  /// Chats currently subscribed, freshest last.
  List<String> get subscribedChatIds => List.unmodifiable(_subscribedChatIds);

  /// Snapshot of the `{chatId: lastSeq}` cursor map.
  Map<String, int> get cursors => Map.unmodifiable(_cursors);

  /// Opens the socket: `{baseWsUrl}/chats/ws/?token=<access_token>` (§7.1).
  ///
  /// Idempotent — a second call while connected or connecting is a no-op, so
  /// an `authProvider` rebuild cannot open a duplicate socket.
  ///
  /// The token is read from secure storage **on every attempt**, never cached
  /// in a field (§10.5): a reconnect after `AuthInterceptor` refreshed the
  /// token must use the new one, and a cached value would guarantee an endless
  /// 1008 loop instead.
  Future<void> connect() async {
    if (_connecting || _channel != null) {
      Logger.debug('ChatSocket: connect() ignored, already connected/connecting');
      return;
    }

    _intentionallyClosed = false;
    _connecting = true;
    _setStatus(
      // Preserve "reconnecting" across a retry so the banner doesn't flicker
      // between states while backoff is running.
      _reconnectAttempt > 0
          ? ChatSocketStatus.reconnecting
          : ChatSocketStatus.connecting,
    );

    try {
      final token = await _secureStorage.read(
        key: AppConstants.accessTokenKey,
      );

      if (token == null || token.isEmpty) {
        // Same end state as a server-side 1008, reached without a pointless
        // round-trip: no token means the handshake cannot succeed.
        Logger.warning('ChatSocket: no access token, not connecting');
        _connecting = false;
        _flagTokenInvalid(closeCode: null, closeReason: 'no stored access token');
        return;
      }

      final uri = _buildUri(token);
      // Logged without the token — this URL carries a bearer credential in its
      // query string and must never reach a log sink or crash report.
      Logger.info('ChatSocket: connecting to ${_redact(uri)}');

      final channel = _channelFactory(uri);
      _channel = channel;

      _channelSubscription = channel.stream.listen(
        _onFrame,
        onError: _onSocketError,
        onDone: _onSocketDone,
        // Errors must not tear down the subscription: onError then onDone is
        // the normal path for a dropped connection, and cancelling early would
        // skip _onSocketDone and with it the reconnect.
        cancelOnError: false,
      );

      // Status stays `connecting` until `ws.ready` — the TCP/HTTP upgrade
      // succeeding does not mean the server has authorised us (§7.2 step 1).
      _connecting = false;
    } catch (error, stackTrace) {
      // A synchronous handshake failure (bad host, DNS, TLS). Not fatal — the
      // network may simply be down — so it feeds the same backoff as a drop.
      Logger.error('ChatSocket: connect failed', error, stackTrace);
      _connecting = false;
      _channel = null;
      _scheduleReconnect();
    }
  }

  /// Closes the socket **and stops reconnecting** (sign-out, or the app
  /// shutting the feature down).
  ///
  /// Clears subscriptions and cursors: they belong to the signed-in user, and
  /// replaying another account's chat ids after a user switch would leak one
  /// user's activity into another's session.
  Future<void> disconnect() async {
    Logger.info('ChatSocket: disconnecting (intentional)');
    _intentionallyClosed = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;

    _stopHeartbeat();

    _subscribedChatIds.clear();
    _cursors.clear();

    await _closeChannel(ws_status.normalClosure);
    _setStatus(ChatSocketStatus.disconnected);
  }

  /// `{"op":"subscribe", "chat_id": …, "last_seq": …}` (§7.3).
  ///
  /// Call when a chat screen opens. Passing [lastSeq] makes the server follow
  /// `ws.subscribed` with a `ws.history` batch covering everything after it —
  /// one round-trip instead of a REST refetch, and the reason the "was the app
  /// backgrounded?" case needs no special handling.
  ///
  /// Remembered locally even when the socket is down, so [_resumeSubscriptions]
  /// can restore it: a subscribe issued during an outage must not be lost.
  void subscribe(String chatId, {int? lastSeq}) {
    if (chatId.isEmpty) return;

    // Re-registering moves the chat to the freshest position — see
    // [_subscribedChatIds] on why order matters.
    _subscribedChatIds
      ..remove(chatId)
      ..add(chatId);

    if (lastSeq != null) {
      // `max`, never assignment: a screen's initial REST page can be *older*
      // than what the socket already delivered, and overwriting a higher
      // cursor with a lower one would replay messages already on screen.
      _cursors[chatId] = max(_cursors[chatId] ?? lastSeq, lastSeq);
    }

    _send({
      'op': 'subscribe',
      'chat_id': chatId,
      if (_cursors[chatId] case final int seq) 'last_seq': seq,
    });
  }

  /// `{"op":"unsubscribe", "chat_id": …}` (§7.3) — the chat screen closed.
  ///
  /// The cursor is **kept** even though the subscription is dropped: the user
  /// is likely to reopen that chat, and a retained cursor turns that into a
  /// gap-filling `ws.history` instead of a blind refetch. [_cursors] is pruned
  /// only on [disconnect] or a `NOT_CHAT_MEMBER` rejection.
  void unsubscribe(String chatId) {
    if (chatId.isEmpty) return;
    _subscribedChatIds.remove(chatId);
    _send({'op': 'unsubscribe', 'chat_id': chatId});
  }

  /// `{"op":"resume", "cursors": {chatId: lastSeq}}` — bulk re-subscribe after
  /// a reconnect (§7.3).
  ///
  /// ⚠️ **Clamps [cursors] to the newest [maxResumeCursors] entries** rather
  /// than trusting the caller. Sending more raises an unwrapped
  /// `MAX_LIMIT_CURSOR` server-side that is *not* delivered as a `ws.error`
  /// and can drop the connection (§7.3) — which reconnects, resends the same
  /// oversized frame, and loops. A caller with 50 cached chats passing them
  /// all in is a realistic mistake, so the guard lives here where it cannot be
  /// forgotten.
  ///
  /// "Newest" = most recently subscribed (LRU order of [_subscribedChatIds]),
  /// falling back to highest `seq` for chats not in that list — a chat with
  /// recent activity is the one the user is most likely looking at.
  void resume(Map<String, int> cursors) {
    if (cursors.isEmpty) return;

    final selected = _selectFreshestCursors(cursors);

    // Merge before sending so a later reconnect still knows about chats that
    // were dropped from *this* resume by the clamp.
    for (final entry in cursors.entries) {
      _cursors[entry.key] = max(_cursors[entry.key] ?? entry.value, entry.value);
    }
    for (final chatId in selected.keys) {
      if (!_subscribedChatIds.contains(chatId)) _subscribedChatIds.add(chatId);
    }

    if (selected.length < cursors.length) {
      Logger.warning(
        'ChatSocket: resume clamped from ${cursors.length} to '
        '${selected.length} cursors (MAX_LIMIT_CURSOR, api-docs §7.3)',
      );
    }

    _send({'op': 'resume', 'cursors': selected});
  }

  /// Releases everything. After this the instance is unusable — one per app.
  Future<void> dispose() async {
    await disconnect();
    _isTokenInvalid.dispose();
    await _eventController.close();
    await _statusController.close();
  }

  // ───────────────────────────── Frame handling ─────────────────────────────

  void _onFrame(dynamic frame) {
    final event = parseWsFrame(frame);

    // Protocol bookkeeping happens before publishing, so that a listener
    // reacting to `ws.ready` already sees the correct heartbeat values and a
    // listener reacting to `new_message` sees an up-to-date cursor.
    switch (event) {
      case WsReady():
        _onReady(event);

      case WsPing():
        // The contract: answer every server ping (§7.2 step 3).
        _send({'op': 'pong'});

      case WsSubscribed():
        // The server's `last_seq` can be ahead of ours if we reconnected after
        // missing messages; take the higher of the two.
        if (event.lastSeq case final int seq) {
          _cursors[event.chatId] = max(_cursors[event.chatId] ?? seq, seq);
        }

      case WsHistory():
        // Advance past a replayed gap so a second reconnect doesn't ask for the
        // same batch again. `next_last_seq` is the server's own continuation
        // cursor and is authoritative over anything derived from the messages.
        if (event.nextLastSeq case final int seq) {
          _cursors[event.chatId] = max(_cursors[event.chatId] ?? seq, seq);
        }

      case WsErrorNotChatMember():
        // Not retryable: we are not (or no longer) a member. Left to the app
        // layer to reconcile — it knows which subscribe was in flight, which
        // this event does not say.
        Logger.warning('ChatSocket: NOT_CHAT_MEMBER (${event.detail ?? "no detail"})');

      case WsErrorBadCommand():
        // A client bug by definition. Loud in logs, invisible to the user.
        Logger.error('ChatSocket: ${event.code} — ${event.detail}');

      case WsUnimplementedEvent():
        // Would mean the backend started publishing typing/call events. Worth
        // a log line precisely because §7.4 says it should not happen.
        Logger.info('ChatSocket: received unpublished event "${event.type}"');

      case NewMessage():
        _advanceCursor(event.chatId, event.seq);

      case MessageEdited():
        _advanceCursor(event.chatId, event.seq);

      case MessageDeleted():
        _advanceCursor(event.chatId, event.seq);

      case MessagesRead():
        // ⚠️ Deliberately does NOT advance the cursor. `messages_read.seq` is
        // a *read watermark*, not a delivery position — and another member's
        // read receipt can reference a seq we have not received yet. Treating
        // it as a delivery cursor would make the next `resume` skip messages
        // we never got, which is a silent, permanent message loss.
        break;

      // No cursor bookkeeping; forwarded straight to consumers.
      case MemberJoined():
      case MemberLeft():
      case MemberKick():
      case MemberBanned():
      case ChatCreated():
      case ChatUpdated():
      case AttachmentSuccess():
      case ChatDeleted():
      case WsUnsubscribed():
      case WsPong():
      case WsAuthInvalid():
      case WsUnknown():
        break;
    }

    if (!_eventController.isClosed) _eventController.add(event);
  }

  void _onReady(WsReady event) {
    Logger.info(
      'ChatSocket: ready (connection ${event.connectionId}, '
      'gateway ${event.gatewayId}, heartbeat ${event.heartbeatInterval}s/'
      '${event.heartbeatTimeout}s)',
    );

    _heartbeatInterval = event.heartbeatInterval;
    _heartbeatTimeout = event.heartbeatTimeout;

    // Only now is the connection usable — and only now is it proven healthy,
    // so this is the right place to reset backoff. Resetting it on the raw
    // socket opening instead would defeat backoff entirely against a gateway
    // that accepts connections and immediately drops them.
    _reconnectAttempt = 0;
    _isTokenInvalid.value = false;
    _setStatus(ChatSocketStatus.ready);

    _startHeartbeat();
    _resumeSubscriptions();
  }

  /// Restores subscriptions after a (re)connect.
  ///
  /// Uses `resume` rather than a burst of `subscribe`s (§7.2, §7.5 step 5):
  /// one frame instead of N, and the server treats it as the documented
  /// reconnect path, replaying each chat's gap from its cursor. Re-subscribing
  /// individually without `last_seq` would silently drop every message missed
  /// during the outage — the exact bug this protocol is designed to prevent.
  void _resumeSubscriptions() {
    if (_subscribedChatIds.isEmpty) return;

    final cursors = <String, int>{};
    for (final chatId in _subscribedChatIds) {
      if (_cursors[chatId] case final int seq) cursors[chatId] = seq;
    }

    if (cursors.isEmpty) {
      // Subscribed, but nothing known about where we left off (a chat opened
      // while offline, or an empty chat). `subscribe` with no `last_seq` is
      // correct here: there is no gap to fill, so no history is wanted.
      for (final chatId in _subscribedChatIds.take(maxResumeCursors)) {
        _send({'op': 'subscribe', 'chat_id': chatId});
      }
      return;
    }

    // resume() re-applies the ≤20 clamp; chats beyond it keep their cursors and
    // are restored when the user next opens them.
    resume(cursors);
  }

  /// Picks the [maxResumeCursors] most relevant entries. See [resume].
  Map<String, int> _selectFreshestCursors(Map<String, int> cursors) {
    if (cursors.length <= maxResumeCursors) return Map.of(cursors);

    final ranked = cursors.keys.toList()
      ..sort((a, b) {
        // Primary: recency of subscription. -1 for chats we hold no
        // subscription for, so they rank below every subscribed chat.
        final rankA = _subscribedChatIds.indexOf(a);
        final rankB = _subscribedChatIds.indexOf(b);
        if (rankA != rankB) return rankB.compareTo(rankA);
        // Tie-break: higher seq means more traffic, so likelier to matter.
        return (cursors[b] ?? 0).compareTo(cursors[a] ?? 0);
      });

    return {
      for (final chatId in ranked.take(maxResumeCursors))
        chatId: cursors[chatId]!,
    };
  }

  void _advanceCursor(String chatId, int seq) {
    final current = _cursors[chatId];
    // Out-of-order or duplicate delivery must not rewind the cursor.
    if (current == null || seq > current) _cursors[chatId] = seq;
  }

  // ───────────────────────────── Heartbeat ─────────────────────────────

  /// Starts the proactive keep-alive.
  ///
  /// Answering `ws.ping` alone would *usually* be enough — but it makes our
  /// liveness entirely dependent on the server's pings arriving. If they are
  /// lost (a proxy buffering, a dozing radio) we stay silent past
  /// [_heartbeatTimeout] and get closed with 1001 without ever knowing why.
  /// Pinging on our own schedule closes that hole.
  ///
  /// The timer ticks every [_heartbeatInterval] but only *sends* when the
  /// connection has actually been idle past the threshold below — so an active
  /// chat generates no keep-alive traffic at all.
  void _startHeartbeat() {
    _stopHeartbeat();

    // 60 % of the server's timeout: early enough that one dropped ping still
    // leaves room for a second attempt before the server gives up, late enough
    // not to chatter on a busy connection. Derived from the value the server
    // sent in `ws.ready`, never a literal (§7.2).
    final idleThreshold = Duration(
      milliseconds: (_heartbeatTimeout * 1000 * 0.6).round(),
    );

    _heartbeatTimer = Timer.periodic(Duration(seconds: _heartbeatInterval), (_) {
      final lastSent = _lastSentAt;
      if (lastSent == null ||
          DateTime.now().difference(lastSent) >= idleThreshold) {
        Logger.debug('ChatSocket: proactive ping (idle)');
        _send({'op': 'ping'});
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastSentAt = null;
  }

  // ───────────────────────── Close / reconnect policy ─────────────────────────

  void _onSocketError(Object error, StackTrace stackTrace) {
    // Almost always followed by onDone, which owns the reconnect; this only
    // records the cause, since the close code alone rarely explains it.
    Logger.error('ChatSocket: socket error', error, stackTrace);
  }

  /// The whole close-code policy (§7.2, §7.5 steps 5–6) in one place.
  void _onSocketDone() {
    final closeCode = _channel?.closeCode;
    final closeReason = _channel?.closeReason;

    Logger.info('ChatSocket: closed (code $closeCode, reason $closeReason)');

    _stopHeartbeat();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;

    if (_intentionallyClosed) {
      _setStatus(ChatSocketStatus.disconnected);
      return;
    }

    switch (closeCode) {
      // 1008 — token missing or rejected, refused *before* `websocket.accept()`
      // (§7.1). The one code that must NOT trigger a retry: the credential is
      // the problem, so reconnecting with it produces a tight, unrecoverable
      // loop. Hand it upward for refresh-or-logout instead.
      case 1008:
        Logger.warning('ChatSocket: closed 1008 — access token invalid, not reconnecting');
        _flagTokenInvalid(closeCode: closeCode, closeReason: closeReason);

      // 1001 — we missed the heartbeat window. 1012 — a third connection
      // evicted us (§7.2 step 4). Neither is a user-visible error and neither
      // needs a message: just reconnect.
      //
      // 1012 gets the *full* backoff on purpose. Two devices both racing to
      // reconnect would otherwise evict each other forever; backoff plus
      // jitter is what lets them settle into the 2-connection budget.
      case 1001:
      case 1012:
        Logger.info('ChatSocket: closed $closeCode (expected), reconnecting quietly');
        _scheduleReconnect();

      default:
        _scheduleReconnect();
    }
  }

  /// Exponential backoff, 1→2→4→8→16→30 s, plus jitter (§7.5 step 5).
  void _scheduleReconnect() {
    if (_intentionallyClosed) return;
    // A pending timer already owns the next attempt; a second would double the
    // rate every time both a socket error and a close arrive.
    if (_reconnectTimer?.isActive ?? false) return;

    final index = min(_reconnectAttempt, _backoffSchedule.length - 1);
    final delay = _backoffSchedule[index] +
        Duration(milliseconds: _random.nextInt(_maxJitterMs));
    _reconnectAttempt++;

    Logger.info(
      'ChatSocket: reconnecting in ${delay.inMilliseconds}ms '
      '(attempt $_reconnectAttempt)',
    );
    _setStatus(ChatSocketStatus.reconnecting);

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_intentionallyClosed) return;
      // Re-reads the token from storage — see [connect].
      connect();
    });
  }

  /// Latches the 1008 signal and emits [WsAuthInvalid].
  ///
  /// Both channels are used because they reach different listeners: the event
  /// for whoever is already consuming [events], the notifier for anything that
  /// attaches later (it latches, the event does not).
  void _flagTokenInvalid({int? closeCode, String? closeReason}) {
    _setStatus(ChatSocketStatus.disconnected);
    if (!_eventController.isClosed) {
      _eventController.add(
        WsAuthInvalid(closeCode: closeCode, closeReason: closeReason),
      );
    }
    _isTokenInvalid.value = true;
  }

  // ───────────────────────────── Plumbing ─────────────────────────────

  /// Builds the connection URL (§7.1).
  ///
  /// The token goes in the **query string**, not a header: `web_socket_channel`
  /// cannot set handshake headers on web, and §7.1 lists the query parameter
  /// first precisely because it behaves identically everywhere.
  Uri _buildUri(String token) {
    // `AppConstants.apiBaseUrl` is `{BASE_URL}/api/v1`; only the scheme changes
    // (http→ws, https→wss) so a single .env value configures both transports.
    final httpUri = Uri.parse('${AppConstants.apiBaseUrl}/chats/ws/');
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';

    return httpUri.replace(
      scheme: wsScheme,
      queryParameters: {
        'token': token,
        if (deviceId case final String id when id.isNotEmpty) 'device_id': id,
      },
    );
  }

  /// [uri] with the token masked, for logs.
  String _redact(Uri uri) {
    return uri
        .replace(
          queryParameters: {
            for (final entry in uri.queryParameters.entries)
              entry.key: entry.key == 'token' ? '<redacted>' : entry.value,
          },
        )
        .toString();
  }

  /// Sends one JSON command, recording the time for the heartbeat.
  ///
  /// Drops the frame when the socket is down rather than queueing it. Deliberate:
  /// every command is either idempotent state the reconnect path rebuilds from
  /// [_subscribedChatIds]/[_cursors] (`subscribe`/`resume`), or a heartbeat that
  /// is meaningless later (`ping`/`pong`). A queue would replay stale
  /// subscriptions for chats the user has since closed.
  void _send(Map<String, dynamic> command) {
    final channel = _channel;
    if (channel == null) {
      Logger.debug('ChatSocket: dropped "${command['op']}" — not connected');
      return;
    }

    try {
      channel.sink.add(jsonEncode(command));
      // Any client frame resets the server's heartbeat timer (§7.2), so every
      // send counts as activity — not just pings.
      _lastSentAt = DateTime.now();
    } catch (error, stackTrace) {
      // A closed sink races with `onDone`; the reconnect path handles it.
      Logger.error('ChatSocket: failed to send "${command['op']}"', error, stackTrace);
    }
  }

  Future<void> _closeChannel(int code) async {
    final subscription = _channelSubscription;
    final channel = _channel;

    _channelSubscription = null;
    _channel = null;

    // Cancelled before closing so `_onSocketDone` doesn't fire for a teardown
    // we already know about (and cannot mistake for a drop worth retrying).
    await subscription?.cancel();
    try {
      await channel?.sink.close(code);
    } catch (error) {
      Logger.warning('ChatSocket: error while closing sink: $error');
    }
  }

  void _setStatus(ChatSocketStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }
}
