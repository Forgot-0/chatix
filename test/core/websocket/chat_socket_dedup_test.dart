import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/core/websocket/ws_event.dart';

import '../../helpers/fakes/fake_secure_storage_service.dart';

/// Covers the api-docs §7.4 at-least-once guarantee: the gateway reads from a
/// Redis stream and `xautoclaim` re-delivers records a crashed gateway left
/// unacknowledged, so **the same frame legitimately arrives twice**.
///
/// `payload.event_id` is the dedup key, and [ChatSocketService] is where it is
/// applied — before consumers, and before cursor bookkeeping. Without it a
/// redelivered `new_message` double-posts a bubble, a redelivered
/// `member_joined` double-counts the roster, and the resume cursor advances
/// twice for one message.
///
/// A fake channel drives the service directly: no server, no timers beyond the
/// ones the service owns.
class _FakeWebSocketSink implements WebSocketSink {
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

class _FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeWebSocketChannel() : _controller = StreamController<dynamic>();

  final StreamController<dynamic> _controller;

  /// Frames the service sent us (`subscribe`, `resume`, `pong`), as raw JSON.
  final _FakeWebSocketSink outbound = _FakeWebSocketSink();

  /// Pushes one server→client frame, as JSON text — the form the real socket
  /// delivers.
  void emit(Map<String, dynamic> frame) => _controller.add(jsonEncode(frame));

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

void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';

  // `_buildUri` reads BASE_URL through AppConstants, which throws if dotenv was
  // never loaded. The URL is irrelevant here — the channel is faked — so an
  // in-memory value is enough.
  setUpAll(() => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'));

  /// A `new_message` frame in the §7.4 envelope.
  Map<String, dynamic> newMessage({required String? eventId, int seq = 1}) => {
    'type': 'new_message',
    'channel': chatId,
    'payload': {
      'event_id': ?eventId,
      'event_name': 'chats.message.sent',
      'event': {'message_id': 'm$seq', 'seq': seq, 'sender_id': 7},
      'message': {'id': 'm$seq', 'chat_id': chatId, 'seq': seq},
    },
    'ts': '2026-01-15T10:30:00Z',
  };

  late _FakeWebSocketChannel channel;
  late ChatSocketService service;

  setUp(() async {
    channel = _FakeWebSocketChannel();
    service = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => channel,
    );
    await service.connect();
  });

  tearDown(() async {
    await service.dispose();
  });

  test('a frame redelivered with the same event_id reaches consumers once', () {
    final received = <WSEvent>[];
    service.events.listen(received.add);

    final frame = newMessage(eventId: 'evt-1');
    channel
      ..emit(frame)
      ..emit(frame);

    return Future<void>.delayed(Duration.zero, () {
      expect(received.whereType<NewMessage>(), hasLength(1));
    });
  });

  test('different event_ids are both delivered', () async {
    final received = <WSEvent>[];
    service.events.listen(received.add);

    channel
      ..emit(newMessage(eventId: 'evt-1', seq: 1))
      ..emit(newMessage(eventId: 'evt-2', seq: 2));

    await Future<void>.delayed(Duration.zero);
    expect(received.whereType<NewMessage>(), hasLength(2));
  });

  test('a frame with no event_id is never suppressed', () async {
    // No key means no way to tell a redelivery from a genuine second event,
    // and dropping a real one is far worse than showing a rare duplicate.
    final received = <WSEvent>[];
    service.events.listen(received.add);

    channel
      ..emit(newMessage(eventId: null))
      ..emit(newMessage(eventId: null));

    await Future<void>.delayed(Duration.zero);
    expect(received.whereType<NewMessage>(), hasLength(2));
  });

  test('a duplicate does not advance the resume cursor a second time', () async {
    // The reason dedup runs *before* bookkeeping: a doubly-advanced cursor
    // would make the next `resume` skip a message that was never delivered.
    service.subscribe(chatId, lastSeq: 1);
    channel.outbound.sent.clear();

    final frame = newMessage(eventId: 'evt-1', seq: 5);
    channel
      ..emit(frame)
      ..emit(frame);
    await Future<void>.delayed(Duration.zero);

    // Re-subscribing without an explicit cursor echoes the service's own
    // tracked `last_seq` — the value a reconnect would resume from.
    service.subscribe(chatId);

    final subscribeFrame = channel.outbound.sent
        .map((raw) => jsonDecode(raw! as String) as Map<String, dynamic>)
        .lastWhere((frame) => frame['op'] == 'subscribe');

    // 5, not 10: the cursor tracks the newest *delivered* seq, and the
    // duplicate delivered nothing new.
    expect(subscribeFrame['last_seq'], 5);
  });

  test('service frames are exempt — they carry no event_id at all', () async {
    final received = <WSEvent>[];
    service.events.listen(received.add);

    const pong = {'type': 'ws.pong', 'payload': <String, dynamic>{}};
    channel
      ..emit(pong)
      ..emit(pong);

    await Future<void>.delayed(Duration.zero);
    expect(received.whereType<WsPong>(), hasLength(2));
  });

  test('disconnect clears seen ids, so another account cannot be suppressed', () async {
    final received = <WSEvent>[];
    service.events.listen(received.add);

    channel.emit(newMessage(eventId: 'evt-1'));
    await Future<void>.delayed(Duration.zero);
    expect(received.whereType<NewMessage>(), hasLength(1));

    await service.disconnect();

    // A fresh session — a user switch, in practice. An id remembered from the
    // previous account must not swallow a real event here.
    final next = _FakeWebSocketChannel();
    final reconnected = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => next,
    );
    addTearDown(reconnected.dispose);
    await reconnected.connect();

    final afterSwitch = <WSEvent>[];
    reconnected.events.listen(afterSwitch.add);

    next.emit(newMessage(eventId: 'evt-1'));
    await Future<void>.delayed(Duration.zero);

    expect(afterSwitch.whereType<NewMessage>(), hasLength(1));
  });
}
