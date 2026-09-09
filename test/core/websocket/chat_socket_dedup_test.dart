import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/core/websocket/ws_event.dart';

import '../../helpers/fakes/fake_secure_storage_service.dart';
import '../../helpers/fakes/fake_web_socket_channel.dart';

void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';

  setUpAll(() => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'));

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

  late FakeWebSocketChannel channel;
  late ChatSocketService service;

  setUp(() async {
    channel = FakeWebSocketChannel();
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
    final received = <WSEvent>[];
    service.events.listen(received.add);

    channel
      ..emit(newMessage(eventId: null))
      ..emit(newMessage(eventId: null));

    await Future<void>.delayed(Duration.zero);
    expect(received.whereType<NewMessage>(), hasLength(2));
  });

  test('a duplicate does not advance the resume cursor a second time', () async {
    service.subscribe(chatId, lastSeq: 1);
    channel.outbound.sent.clear();

    final frame = newMessage(eventId: 'evt-1', seq: 5);
    channel
      ..emit(frame)
      ..emit(frame);
    await Future<void>.delayed(Duration.zero);

    service.subscribe(chatId);

    final subscribeFrame = channel.outbound.sent
        .map((raw) => jsonDecode(raw! as String) as Map<String, dynamic>)
        .lastWhere((frame) => frame['op'] == 'subscribe');

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

    final next = FakeWebSocketChannel();
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
