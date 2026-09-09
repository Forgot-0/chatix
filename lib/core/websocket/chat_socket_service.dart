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

enum ChatSocketStatus { disconnected, connecting, ready, reconnecting }

class ChatSocketService {
  ChatSocketService({
    required SecureStorageService secureStorage,
    this.deviceId,
    Uri Function(Uri uri)? channelFactoryUri,
    WebSocketChannel Function(Uri uri)? channelFactory,
  }) : _secureStorage = secureStorage,
       _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final SecureStorageService _secureStorage;

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

  final Map<String, int> _cursors = {};

  int _heartbeatInterval = 30;

  int _heartbeatTimeout = 75;

  Timer? _heartbeatTimer;

  DateTime? _lastSentAt;

  Timer? _reconnectTimer;

  int _reconnectAttempt = 0;

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

  Future<void> connect() async {
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
      final token = await _secureStorage.read(key: AppConstants.accessTokenKey);

      if (token == null || token.isEmpty) {
        Logger.warning('ChatSocket: no access token, not connecting');
        _connecting = false;
        _flagTokenInvalid(
          closeCode: null,
          closeReason: 'no stored access token',
        );
        return;
      }

      final uri = _buildUri(token);
      Logger.info('ChatSocket: connecting to ${_redact(uri)}');

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

    await _closeChannel(ws_status.normalClosure);
    _setStatus(ChatSocketStatus.disconnected);
  }

  void subscribe(String chatId, {int? lastSeq}) {
    if (chatId.isEmpty) return;

    _subscribedChatIds
      ..remove(chatId)
      ..add(chatId);

    if (lastSeq != null) {
      _cursors[chatId] = max(_cursors[chatId] ?? lastSeq, lastSeq);
    }

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
      _cursors[entry.key] = max(
        _cursors[entry.key] ?? entry.value,
        entry.value,
      );
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

  Future<void> dispose() async {
    await disconnect();
    _isTokenInvalid.dispose();
    await _eventController.close();
    await _statusController.close();
  }

  void _onFrame(dynamic frame) {
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
          _cursors[event.chatId] = max(_cursors[event.chatId] ?? seq, seq);
        }

      case WsHistory():
        if (event.nextLastSeq case final int seq) {
          _cursors[event.chatId] = max(_cursors[event.chatId] ?? seq, seq);
        }

      case WsErrorNotChatMember():
        Logger.warning(
          'ChatSocket: NOT_CHAT_MEMBER (${event.detail ?? "no detail"})',
        );

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
    _isTokenInvalid.value = false;
    _setStatus(ChatSocketStatus.ready);

    _startHeartbeat();
    _resumeSubscriptions();
  }

  void _resumeSubscriptions() {
    if (_subscribedChatIds.isEmpty) return;

    final cursors = <String, int>{};
    for (final chatId in _subscribedChatIds) {
      if (_cursors[chatId] case final int seq) cursors[chatId] = seq;
    }

    if (cursors.isEmpty) {
      for (final chatId in _subscribedChatIds.take(maxResumeCursors)) {
        _send({'op': 'subscribe', 'chat_id': chatId});
      }
      return;
    }

    resume(cursors);
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
    final current = _cursors[chatId];
    if (current == null || seq > current) _cursors[chatId] = seq;
  }

  void _startHeartbeat() {
    _stopHeartbeat();

    final idleThreshold = Duration(
      milliseconds: (_heartbeatTimeout * 1000 * 0.6).round(),
    );

    _heartbeatTimer = Timer.periodic(Duration(seconds: _heartbeatInterval), (
      _,
    ) {
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

    _stopHeartbeat();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;

    if (_intentionallyClosed) {
      _setStatus(ChatSocketStatus.disconnected);
      return;
    }

    switch (closeCode) {
      case 1008:
        Logger.warning(
          'ChatSocket: closed 1008 — access token invalid, not reconnecting',
        );
        _flagTokenInvalid(closeCode: closeCode, closeReason: closeReason);

      case 1001:
      case 1012:
        Logger.info(
          'ChatSocket: closed $closeCode (expected), reconnecting quietly',
        );
        _scheduleReconnect();

      default:
        _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_intentionallyClosed) return;
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
      if (_intentionallyClosed) return;
      connect();
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

    return httpUri.replace(
      scheme: wsScheme,
      queryParameters: {
        'token': token,
        if (deviceId case final String id when id.isNotEmpty) 'device_id': id,
      },
    );
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
      return;
    }

    try {
      channel.sink.add(jsonEncode(command));
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
