import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Collects everything the client sends, so a test can assert on the commands
/// (`subscribe`, `resume`, `pong`, ...) the socket service emits.
class FakeWebSocketSink implements WebSocketSink {
  final List<Object?> sent = [];
  final Completer<void> _done = Completer<void>();

  @override
  Future<void> get done => _done.future;

  @override
  void add(Object? data) => sent.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Object?> stream) async {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) _done.complete();
  }
}

/// In-memory stand-in for a live socket: `emit` pushes a server frame at the
/// client exactly as the gateway would, without any network.
class FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  /// Broadcast on purpose: `close()` on a single-subscription controller that
  /// was never listened to never completes, which would hang the tearDown of
  /// any test that builds the socket without connecting. Broadcast also lets a
  /// reconnect re-listen to the same fake channel.
  FakeWebSocketChannel() : _controller = StreamController<dynamic>.broadcast();

  final StreamController<dynamic> _controller;

  final FakeWebSocketSink outbound = FakeWebSocketSink();

  /// Everything the client sent, decoded.
  List<Map<String, dynamic>> get commands => [
    for (final frame in outbound.sent)
      if (frame is String)
        if (jsonDecode(frame) case final Map<String, dynamic> command) command,
  ];

  /// The `op` of every command sent, in order.
  List<String> get ops => [
    for (final command in commands)
      if (command['op'] case final String op) op,
  ];

  void emit(Map<String, dynamic> frame) => _controller.add(jsonEncode(frame));

  /// The gateway hanging up, with the code it hung up with.
  ///
  /// Close codes are the whole of the socket's error handling — 1001, 1008
  /// and 1012 mean three different things and lead to three different
  /// recoveries (api-docs §6.2) — so a fake that cannot report one cannot
  /// test any of them.
  void serverClose(int code, [String? reason]) {
    closeCode = code;
    closeReason = reason;
    dispose();
  }

  Future<void> dispose() async {
    if (_controller.isClosed) return;
    await _controller.close();
  }

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  WebSocketSink get sink => outbound;

  @override
  int? closeCode;

  @override
  String? closeReason;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();
}
