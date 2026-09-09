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

  void emit(Map<String, dynamic> frame) => _controller.add(jsonEncode(frame));

  Future<void> dispose() => _controller.close();

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  WebSocketSink get sink => outbound;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();
}
