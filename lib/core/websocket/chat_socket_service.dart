import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/storage/secure_storage_service.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/socket_cursor_store.dart';
import 'package:chatix/core/websocket/socket_protocol_log.dart';
import 'package:chatix/core/websocket/socket_token_source.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/core/websocket/ws_event_parser.dart';

enum ChatSocketStatus { disconnected, connecting, ready, reconnecting }

class ChatSocketService {
  ChatSocketService({
    required SecureStorageService secureStorage,
    this.deviceId,
    Uri Function(Uri uri)? channelFactoryUri,
    WebSocketChannel Function(Uri uri)? channelFactory,
    SocketCursorStore? cursorStore,
    SocketTokenSource? tokenSource,
    SocketProtocolLog? protocolLog,
  }) : _secureStorage = secureStorage,
       _cursorStore = cursorStore,
       _tokenSource = tokenSource,
       _protocolLog = protocolLog,
       _channelFactory = channelFactory ?? WebSocketChannel.connect {
    _seedCursors();
  }

  final SecureStorageService _secureStorage;

  /// Where the resume cursors are kept across runs, if anywhere.
  final SocketCursorStore? _cursorStore;

  /// How a token good enough to connect with is obtained.
  ///
  /// Without one the socket can only use whatever was last written to
  /// storage, which after any pause longer than five minutes is a token the
  /// gateway will close the connection over (api-docs §0, §6.1).
  final SocketTokenSource? _tokenSource;

  /// Where the conversation is recorded, when anyone asked for it.
  final SocketProtocolLog? _protocolLog;

  final String? deviceId;

  final WebSocketChannel Function(Uri uri) _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;

  final StreamController<WSEvent> _eventController =
      StreamController<WSEvent>.broadcast();

  final StreamController<ChatSocketStatus> _statusController =
      StreamController<ChatSocketStatus>.broadcast();

  ChatSocketStatus _status = ChatSocketStatus.disconnected;

  bool _intentionallyClosed = true;

  bool _connecting = false;

  final Set<String> _seenEventIds = <String>{};

  static const int _seenEventIdsLimit = 512;

  bool _isDuplicate(WSEvent event) {
    if (event is! WSDomainEvent) return false;

    final id = event.eventId;
    if (id == null || id.isEmpty) return false;

    if (!_seenEventIds.add(id)) return true;

    if (_seenEventIds.length > _seenEventIdsLimit) {
      _seenEventIds.remove(_seenEventIds.first);
    }
    return false;
  }

  final List<String> _subscribedChatIds = [];

  /// The chat of the subscribe most recently put on the wire. `ws.error` has no
  /// channel field, so this is what lets a rejection be attributed to a chat.
  String? _lastSubscribeTarget;

  /// Set when the connection URL already asked the gateway to subscribe, so
  /// `_resumeSubscriptions` does not repeat the request (api-docs §6.1).
  String? _initialSubscribeSent;

  final Map<String, int> _cursors = {};

  /// When the connection went down, while it is down.
  DateTime? _offlineSince;

  /// How long the connection was gone for, most recently.
  ///
  /// The number a chat screen decides with: a short blink is what `resume`
  /// and `ws.history` are for, and a long one is a reason to stop trusting
  /// the window on screen and fetch it again.
  Duration? _lastOutage;

  Duration? get lastOutage => _lastOutage;

  DateTime? get offlineSince => _offlineSince;

  int _heartbeatInterval = 30;

  int _heartbeatTimeout = 75;

  Timer? _heartbeatTimer;

  DateTime? _lastSentAt;

  Timer? _reconnectTimer;

  int _reconnectAttempt = 0;

  /// How many `1008` closes in a row we have answered with a fresh token.
  ///
  /// One is a token that expired while we were away, which is ordinary. Two
  /// in a row means the renewed token was refused too, and the session really
  /// is over — retrying past that is a loop that empties a battery.
  int _consecutiveTokenRejections = 0;

  static const int maxTokenRejections = 1;

  /// Whether the app is in the background.
  ///
  /// Not the same as disconnected: a paused socket may still be connected,
  /// just subscribed to nothing and pinging rarely. Nothing reconnects while
  /// this is set — coming back to the foreground is what does.
  bool _paused = false;

  /// Chats to re-subscribe to when the app comes back.
  final Map<String, int> _pausedCursors = {};

  static const List<Duration> _backoffSchedule = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  static const int _maxJitterMs = 400;

  final Random _random = Random();

  static const int maxResumeCursors = 20;

  Stream<WSEvent> get events => _eventController.stream;

  Stream<ChatSocketStatus> get statusStream => _statusController.stream;

  ChatSocketStatus get status => _status;

  ValueListenable<bool> get isTokenInvalid => _isTokenInvalid;
  final ValueNotifier<bool> _isTokenInvalid = ValueNotifier<bool>(false);

  List<String> get subscribedChatIds => List.unmodifiable(_subscribedChatIds);

  Map<String, int> get cursors => Map.unmodifiable(_cursors);

  /// Brings back whatever cursors the last run left behind.
  ///
  /// Only ever forward: a stored cursor that is behind what this run has
  /// already seen would ask the gateway to replay messages that are on
  /// screen.
  void _seedCursors() {
    final stored = _cursorStore?.load();
    if (stored == null || stored.isEmpty) return;

    for (final entry in stored.entries) {
      final known = _cursors[entry.key];
      if (known == null || entry.value > known) {
        _cursors[entry.key] = entry.value;
      }
    }
  }

  /// A token the gateway will still accept when the handshake arrives.
  ///
  /// The token travels in the connect URL (api-docs §6.1) and lives five
  /// minutes (§0), and a handshake refused for a stale one costs a whole
  /// reconnect cycle rather than a retried request — so it is checked and, if
  /// need be, renewed *before* connecting rather than after being refused.
  /// With no source to renew it, this is what it always was: whatever is in
  /// storage, read afresh on every attempt and never held in a field.
  Future<String?> _freshToken({required bool forceRefresh}) async {
    final source = _tokenSource;
    if (source == null) {
      return _secureStorage.read(key: AppConstants.accessTokenKey);
    }

    try {
      return await source.token(forceRefresh: forceRefresh);
    } catch (error, stackTrace) {
      Logger.error('ChatSocket: could not obtain a token', error, stackTrace);
      // Falling back to what is stored: a renewal that failed because the
      // network is down should not stop us trying a token that may well
      // still be good.
      return _secureStorage.read(key: AppConstants.accessTokenKey);
    }
  }

  /// Opens the connection.
  ///
  /// [forceTokenRefresh] is what a `1008` close asks for: the gateway has
  /// already refused the token that is in storage, so reading it again and
  /// presenting it again would be refused again.
  Future<void> connect({bool forceTokenRefresh = false}) async {
    _seedCursors();

    if (_paused) {
      Logger.debug('ChatSocket: connect() ignored, paused in the background');
      return;
    }

    if (_connecting || _channel != null) {
      Logger.debug(
        'ChatSocket: connect() ignored, already connected/connecting',
      );
      return;
    }

    _intentionallyClosed = false;
    _connecting = true;
    _setStatus(
      _reconnectAttempt > 0
          ? ChatSocketStatus.reconnecting
          : ChatSocketStatus.connecting,
    );

    try {
      final token = await _freshToken(forceRefresh: forceTokenRefresh);

      if (token == null || token.isEmpty) {
        Logger.warning('ChatSocket: no usable access token, not connecting');
        _connecting = false;
        _protocolLog?.note('connect aborted: no usable access token');
        _flagTokenInvalid(
          closeCode: null,
          closeReason: 'no usable access token',
        );
        return;
      }

      final uri = _buildUri(token);
      _initialSubscribeSent = uri.queryParameters['initial_chat_id'];
      Logger.info('ChatSocket: connecting to ${_redact(uri)}');
      _protocolLog?.note('connecting to ${_redact(uri)}');

      final channel = _channelFactory(uri);
      _channel = channel;

      _channelSubscription = channel.stream.listen(
        _onFrame,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: false,
      );

      _connecting = false;
    } catch (error, stackTrace) {
      Logger.error('ChatSocket: connect failed', error, stackTrace);
      _connecting = false;
      _channel = null;
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    Logger.info('ChatSocket: disconnecting (intentional)');
    _intentionallyClosed = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;

    _stopHeartbeat();

    _subscribedChatIds.clear();
    _cursors.clear();
    _seenEventIds.clear();
    _lastSubscribeTarget = null;
    _initialSubscribeSent = null;
    _consecutiveTokenRejections = 0;
    _paused = false;
    _pausedCursors.clear();

    await _closeChannel(ws_status.normalClosure);
    _setStatus(ChatSocketStatus.disconnected);
  }

  void subscribe(String chatId, {int? lastSeq}) {
    if (chatId.isEmpty) return;

    _subscribedChatIds
      ..remove(chatId)
      ..add(chatId);

    if (lastSeq != null) _advanceCursor(chatId, lastSeq);

    _lastSubscribeTarget = chatId;
    _send({
      'op': 'subscribe',
      'chat_id': chatId,
      if (_cursors[chatId] case final int seq) 'last_seq': seq,
    });
  }

  void unsubscribe(String chatId) {
    if (chatId.isEmpty) return;
    _subscribedChatIds.remove(chatId);
    _send({'op': 'unsubscribe', 'chat_id': chatId});
  }

  void resume(Map<String, int> cursors) {
    if (cursors.isEmpty) return;

    final selected = _selectFreshestCursors(cursors);

    for (final entry in cursors.entries) {
      _advanceCursor(entry.key, entry.value);
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

  /// The app went to the background.
  ///
  /// Two things happen. The chat subscriptions are dropped, because a screen
  /// nobody is looking at does not need a fan-out and the gateway checks
  /// subscriptions before delivering (api-docs §6.4) — the messages are not
  /// lost, they are replayed from the cursor on the way back. And the
  /// proactive ping stretches out: the platform will suspend our timers
  /// anyway, and a socket the gateway closes on a heartbeat timeout is a
  /// `1001`, which is an ordinary reconnect.
  ///
  /// Idempotent, because the platform is free to send the same lifecycle
  /// state twice.
  void pauseForBackground() {
    if (_paused) return;
    _paused = true;

    Logger.info('ChatSocket: pausing (${_subscribedChatIds.length} chats)');
    _protocolLog?.note('paused, ${_subscribedChatIds.length} subscriptions');

    _pausedCursors
      ..clear()
      ..addEntries([
        for (final chatId in _subscribedChatIds)
          if (_cursors[chatId] case final int seq) MapEntry(chatId, seq),
      ]);

    for (final chatId in [..._subscribedChatIds]) {
      _send({'op': 'unsubscribe', 'chat_id': chatId});
    }
    _subscribedChatIds.clear();

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Restarted at the background interval rather than stopped: the gateway
    // still closes a connection that says nothing for `heartbeat_timeout`
    // (api-docs §6.2), and staying connected through a short excursion out of
    // the app is worth one frame a minute. Nothing to keep alive if the
    // connection is already gone.
    if (_channel != null) _startHeartbeat();
  }

  /// The app came back.
  ///
  /// Everything that was open before is re-subscribed in one `resume` with
  /// the cursors it had, so whatever arrived while we were away is replayed
  /// rather than missed (api-docs §6.3). A connection that did not survive
  /// the background is rebuilt first.
  void resumeFromBackground() {
    if (!_paused) return;
    _paused = false;

    Logger.info(
      'ChatSocket: resuming (${_pausedCursors.length} chats to restore)',
    );
    _protocolLog?.note('resumed, ${_pausedCursors.length} cursors to restore');

    // Back to the foreground rhythm. A connection that did not survive gets
    // its heartbeat from `ws.ready` instead, below.
    if (_channel != null) _startHeartbeat();

    final restoring = Map<String, int>.from(_pausedCursors);
    _pausedCursors.clear();

    if (_channel == null) {
      // The subscriptions are remembered on the way back up, so that whether
      // the connection survived the background changes nothing: either
      // `resume` goes out now, or `_resumeSubscriptions` sends it after the
      // handshake.
      for (final chatId in restoring.keys) {
        if (!_subscribedChatIds.contains(chatId)) {
          _subscribedChatIds.add(chatId);
        }
      }
      _reconnectAttempt = 0;
      unawaited(connect());
      return;
    }

    if (restoring.isEmpty) return;
    resume(restoring);
  }

  Future<void> dispose() async {
    await disconnect();
    _isTokenInvalid.dispose();
    await _eventController.close();
    await _statusController.close();
  }

  void _onFrame(dynamic frame) {
    _protocolLog?.record(SocketFrameDirection.inbound, frame.toString());

    final event = parseWsFrame(frame);

    if (_isDuplicate(event)) {
      Logger.debug(
        'ChatSocket: dropped duplicate ${event.type} '
        '(event_id ${(event as WSDomainEvent).eventId})',
      );
      return;
    }

    switch (event) {
      case WsReady():
        _onReady(event);

      case WsPing():
        _send({'op': 'pong'});

      case WsSubscribed():
        if (event.lastSeq case final int seq) {
          _advanceCursor(event.chatId, seq);
        }

      case WsHistory():
        if (event.nextLastSeq case final int seq) {
          _advanceCursor(event.chatId, seq);
        }

      case WsErrorNotChatMember():
        Logger.warning(
          'ChatSocket: NOT_CHAT_MEMBER (${event.detail ?? "no detail"})',
        );
        // Attribute it to the subscribe being answered, then stop tracking the
        // chat: the gateway will not send us its events.
        final rejected = event.chatId ?? _lastSubscribeTarget;
        if (rejected != null) _subscribedChatIds.remove(rejected);
        if (!_eventController.isClosed) {
          _eventController.add(event.withChatId(rejected));
        }
        return;

      case WsErrorBadCommand():
        Logger.error('ChatSocket: ${event.code} — ${event.detail}');

      case WsUnimplementedEvent():
        Logger.info('ChatSocket: received unpublished event "${event.type}"');

      case WSMessageEvent():
        if (event.seq case final int seq) {
          _advanceCursor(event.chatId, seq);
        }

      case MessagesRead():
      case ReactionUpdated():
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

    _reconnectAttempt = 0;
    _consecutiveTokenRejections = 0;
    _isTokenInvalid.value = false;

    final wentDownAt = _offlineSince;
    _lastOutage = wentDownAt == null
        ? null
        : DateTime.now().difference(wentDownAt);
    _offlineSince = null;

    _setStatus(ChatSocketStatus.ready);

    _startHeartbeat();
    _resumeSubscriptions();
  }

  void _resumeSubscriptions() {
    // The gateway has already subscribed us to this one from the handshake;
    // asking again would just duplicate the ws.history it is about to send.
    final alreadySubscribed = _initialSubscribeSent;
    _initialSubscribeSent = null;

    // Most recently opened first, which is the order both halves below are
    // trimmed in: if something has to be left out, it is the chat nobody has
    // looked at in longest.
    final pending = [
      for (final chatId in _subscribedChatIds.reversed)
        if (chatId != alreadySubscribed) chatId,
    ];
    if (pending.isEmpty) return;

    final cursors = <String, int>{};
    final cursorless = <String>[];
    for (final chatId in pending) {
      if (_cursors[chatId] case final int seq) {
        cursors[chatId] = seq;
      } else {
        cursorless.add(chatId);
      }
    }

    // Both halves go out. A chat with a cursor is resumed so the gateway
    // replays what it missed; a chat without one — never opened on this
    // device, or opened before the cache was cleared — is simply subscribed.
    // Dropping the second group, as this used to, meant a chat silently
    // receiving nothing for the rest of the connection.
    if (cursors.isNotEmpty) resume(cursors);

    if (cursorless.isEmpty) return;

    // The 20-key cap is on `resume` specifically (api-docs §6.3), but a
    // hundred individual subscribes is its own kind of rude; the same bound
    // is a reasonable one to keep.
    final budget = maxResumeCursors - (cursors.isEmpty ? 0 : cursors.length);
    if (budget <= 0) {
      Logger.warning(
        'ChatSocket: ${cursorless.length} chats left unsubscribed, the '
        'resume budget went to chats with cursors',
      );
      return;
    }

    for (final chatId in cursorless.take(budget)) {
      _lastSubscribeTarget = chatId;
      _send({'op': 'subscribe', 'chat_id': chatId});
    }
  }

  Map<String, int> _selectFreshestCursors(Map<String, int> cursors) {
    if (cursors.length <= maxResumeCursors) return Map.of(cursors);

    final ranked = cursors.keys.toList()
      ..sort((a, b) {
        final rankA = _subscribedChatIds.indexOf(a);
        final rankB = _subscribedChatIds.indexOf(b);
        if (rankA != rankB) return rankB.compareTo(rankA);
        return (cursors[b] ?? 0).compareTo(cursors[a] ?? 0);
      });

    return {
      for (final chatId in ranked.take(maxResumeCursors))
        chatId: cursors[chatId]!,
    };
  }

  void _advanceCursor(String chatId, int seq) {
    if (chatId.isEmpty) return;

    final current = _cursors[chatId];
    if (current != null && seq <= current) return;

    _cursors[chatId] = seq;
    _cursorStore?.save(chatId, seq);
  }

  /// How often the proactive ping goes out while the app is in the
  /// background, as a share of `heartbeat_timeout`.
  ///
  /// In the foreground the ping is generous — it goes out well inside the
  /// window, so a slow network still leaves room. In the background the point
  /// is the opposite: say as little as possible while still staying inside
  /// the window the gateway closes on (api-docs §6.2). Missing it is not a
  /// failure either — it is a `1001`, which is an ordinary reconnect.
  static const double _backgroundHeartbeatShare = 0.8;

  void _startHeartbeat() {
    _stopHeartbeat();

    final idleThreshold = Duration(
      milliseconds: (_heartbeatTimeout * 1000 * (_paused ? 0.75 : 0.6)).round(),
    );

    final period = _paused
        ? Duration(
            milliseconds: (_heartbeatTimeout * 1000 * _backgroundHeartbeatShare)
                .round(),
          )
        : Duration(seconds: _heartbeatInterval);

    _heartbeatTimer = Timer.periodic(period, (_) {
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

  void _onSocketError(Object error, StackTrace stackTrace) {
    Logger.error('ChatSocket: socket error', error, stackTrace);
  }

  void _onSocketDone() {
    final closeCode = _channel?.closeCode;
    final closeReason = _channel?.closeReason;

    Logger.info('ChatSocket: closed (code $closeCode, reason $closeReason)');
    _protocolLog?.note('closed: code $closeCode, reason $closeReason');

    _stopHeartbeat();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;

    if (_intentionallyClosed) {
      _offlineSince = null;
      _setStatus(ChatSocketStatus.disconnected);
      return;
    }

    _offlineSince ??= DateTime.now();

    switch (closeCode) {
      // The token was missing or would not do. It is five minutes old at
      // most (api-docs §0), so the overwhelming case is simply that it
      // expired while we were away — renew it and come back, rather than
      // ending a session that is not over.
      case 1008:
        _consecutiveTokenRejections++;

        if (_consecutiveTokenRejections > maxTokenRejections) {
          Logger.warning(
            'ChatSocket: closed 1008 again after a refresh — the session is '
            'over, not reconnecting',
          );
          _protocolLog?.note('closed 1008 after a refresh; giving up');
          _flagTokenInvalid(closeCode: closeCode, closeReason: closeReason);
          return;
        }

        Logger.info(
          'ChatSocket: closed 1008 — renewing the access token and '
          'reconnecting (attempt $_consecutiveTokenRejections)',
        );
        _scheduleReconnect(forceTokenRefresh: true);

      // Heartbeat timeout: we went quiet for longer than the gateway allows
      // (api-docs §6.2). An ordinary reconnect, and `resume` fills the gap.
      case 1001:
        Logger.info('ChatSocket: closed 1001 (heartbeat), reconnecting');
        _scheduleReconnect();

      // A third connection on this account displaced the oldest — this one
      // (api-docs §6.2). Not an error and not the user's problem: reconnect
      // without saying anything to anybody.
      case 1012:
        Logger.info(
          'ChatSocket: closed 1012 (connection limit), reconnecting quietly',
        );
        _scheduleReconnect();

      default:
        _scheduleReconnect();
    }
  }

  void _scheduleReconnect({bool forceTokenRefresh = false}) {
    if (_intentionallyClosed) return;
    if (_paused) {
      // Nothing to reconnect to while the app is in the background; coming
      // back to the foreground is what starts this again.
      Logger.debug('ChatSocket: paused, not scheduling a reconnect');
      return;
    }
    if (_reconnectTimer?.isActive ?? false) return;

    final index = min(_reconnectAttempt, _backoffSchedule.length - 1);
    final delay =
        _backoffSchedule[index] +
        Duration(milliseconds: _random.nextInt(_maxJitterMs));
    _reconnectAttempt++;

    Logger.info(
      'ChatSocket: reconnecting in ${delay.inMilliseconds}ms '
      '(attempt $_reconnectAttempt)',
    );
    _setStatus(ChatSocketStatus.reconnecting);

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_intentionallyClosed || _paused) return;
      connect(forceTokenRefresh: forceTokenRefresh);
    });
  }

  void _flagTokenInvalid({int? closeCode, String? closeReason}) {
    _setStatus(ChatSocketStatus.disconnected);
    if (!_eventController.isClosed) {
      _eventController.add(
        WsAuthInvalid(closeCode: closeCode, closeReason: closeReason),
      );
    }
    _isTokenInvalid.value = true;
  }

  Uri _buildUri(String token) {
    final httpUri = Uri.parse('${AppConstants.apiBaseUrl}/chats/ws/');
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';

    // With `initial_chat_id` + `initial_last_seq` the gateway subscribes for us
    // right after `ws.ready`, saving a whole round-trip on every reconnect
    // (api-docs §6.1). Only worth it when there is exactly one chat to resume —
    // the usual case, since the open chat screen is the only subscriber — and
    // both parameters have to be sent together or neither.
    final initial = _initialSubscribeCandidate();

    return httpUri.replace(
      scheme: wsScheme,
      queryParameters: {
        'token': token,
        if (deviceId case final String id when id.isNotEmpty) 'device_id': id,
        if (initial != null) ...{
          'initial_chat_id': initial.chatId,
          'initial_last_seq': '${initial.lastSeq}',
        },
      },
    );
  }

  ({String chatId, int lastSeq})? _initialSubscribeCandidate() {
    if (_subscribedChatIds.length != 1) return null;
    final chatId = _subscribedChatIds.single;
    final seq = _cursors[chatId];
    if (seq == null) return null;
    return (chatId: chatId, lastSeq: seq);
  }

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

  void _send(Map<String, dynamic> command) {
    final channel = _channel;
    if (channel == null) {
      Logger.debug('ChatSocket: dropped "${command['op']}" — not connected');
      _protocolLog?.note('dropped "${command['op']}" — not connected');
      return;
    }

    try {
      final encoded = jsonEncode(command);
      channel.sink.add(encoded);
      _protocolLog?.record(SocketFrameDirection.outbound, encoded);
      _lastSentAt = DateTime.now();
    } catch (error, stackTrace) {
      Logger.error(
        'ChatSocket: failed to send "${command['op']}"',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _closeChannel(int code) async {
    final subscription = _channelSubscription;
    final channel = _channel;

    _channelSubscription = null;
    _channel = null;

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
