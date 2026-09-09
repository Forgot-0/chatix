import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/core/websocket/ws_event.dart';

import '../../helpers/fakes/fake_secure_storage_service.dart';
import '../../helpers/fakes/fake_web_socket_channel.dart';

/// The handshake shortcut (`initial_chat_id` + `initial_last_seq`, api-docs
/// §6.1) and the attribution of `ws.error`, which carries no channel of its own.
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';
  const otherChatId = 'a3f1c2d4-0000-4000-8000-000000000009';

  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  late List<FakeWebSocketChannel> channels;
  late List<Uri> uris;
  late ChatSocketService socket;

  setUp(() {
    channels = [];
    uris = [];
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (uri) {
        uris.add(uri);
        final channel = FakeWebSocketChannel();
        channels.add(channel);
        return channel;
      },
    );
  });

  tearDown(() async {
    await socket.dispose();
    for (final open in channels) {
      await open.dispose();
    }
  });

  FakeWebSocketChannel channel() => channels.last;

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Map<String, dynamic> ready() => {
    'type': 'ws.ready',
    'payload': {
      'connection_id': 'c1',
      'gateway_id': 'g1',
      'heartbeat_interval': 30,
      'heartbeat_timeout': 75,
    },
  };

  List<Map<String, dynamic>> sent() => [
    for (final frame in channel().outbound.sent)
      jsonDecode(frame! as String) as Map<String, dynamic>,
  ];

  group('initial subscribe on the handshake', () {
    test('a fresh connection carries no initial chat', () async {
      await socket.connect();

      expect(
        uris.single.queryParameters.containsKey('initial_chat_id'),
        isFalse,
      );
    });

    test('a reconnect asks the gateway to subscribe for us', () async {
      await socket.connect();
      socket.subscribe(chatId, lastSeq: 41);
      await settle();

      // Drop the socket the way a network blip would.
      await channel().dispose();
      await settle();

      await socket.connect();

      expect(uris.last.queryParameters['initial_chat_id'], chatId);
      expect(uris.last.queryParameters['initial_last_seq'], '41');
    });

    test(
      'the round-trip it saves is not then spent on a duplicate subscribe',
      () async {
        await socket.connect();
        socket.subscribe(chatId, lastSeq: 41);
        await settle();

        await channel().dispose();
        await settle();
        await socket.connect();

        channel().emit(ready());
        await settle();

        // The gateway already subscribed us from the URL; asking again would
        // only duplicate the ws.history it is about to send.
        expect(
          sent().where((c) => c['op'] == 'subscribe' || c['op'] == 'resume'),
          isEmpty,
        );
      },
    );

    test('other chats are still resumed alongside the handshake one', () async {
      await socket.connect();
      socket.subscribe(chatId, lastSeq: 41);
      socket.subscribe(otherChatId, lastSeq: 7);
      await settle();

      await channel().dispose();
      await settle();
      await socket.connect();

      // Two candidates means no shortcut — it only carries one chat.
      expect(uris.last.queryParameters.containsKey('initial_chat_id'), isFalse);

      channel().emit(ready());
      await settle();

      final resume = sent().firstWhere((c) => c['op'] == 'resume');
      expect(
        (resume['cursors'] as Map).keys,
        containsAll([chatId, otherChatId]),
      );
    });

    test('a chat with no known cursor cannot use the shortcut', () async {
      await socket.connect();
      socket.subscribe(chatId);
      await settle();

      await channel().dispose();
      await settle();
      await socket.connect();

      // Both parameters go together or neither (§6.1).
      expect(uris.last.queryParameters.containsKey('initial_chat_id'), isFalse);
    });
  });

  group('ws.error attribution', () {
    test('NOT_CHAT_MEMBER is pinned to the subscribe it answers', () async {
      await socket.connect();

      final seen = <WsErrorNotChatMember>[];
      final sub = socket.events.listen((event) {
        if (event is WsErrorNotChatMember) seen.add(event);
      });
      addTearDown(sub.cancel);

      socket.subscribe(chatId, lastSeq: 1);
      await settle();

      channel().emit({
        'type': 'ws.error',
        'code': 'NOT_CHAT_MEMBER',
        'detail': 'not a member',
        'ts': '2026-01-15T10:30:00Z',
      });
      await settle();

      expect(seen, hasLength(1));
      expect(seen.single.chatId, chatId);
    });

    test('a refused chat stops being tracked for resume', () async {
      await socket.connect();
      socket.subscribe(chatId, lastSeq: 1);
      await settle();
      expect(socket.subscribedChatIds, contains(chatId));

      channel().emit({
        'type': 'ws.error',
        'code': 'NOT_CHAT_MEMBER',
        'detail': 'not a member',
      });
      await settle();

      // Re-subscribing on every reconnect to a chat we are barred from would
      // just earn the same rejection forever.
      expect(socket.subscribedChatIds, isNot(contains(chatId)));
    });

    test('an unrelated ws.error is left alone', () async {
      await socket.connect();

      final seen = <WSEvent>[];
      final sub = socket.events.listen(seen.add);
      addTearDown(sub.cancel);

      socket.subscribe(chatId, lastSeq: 1);
      await settle();

      channel().emit({
        'type': 'ws.error',
        'code': 'BAD_COMMAND',
        'detail': 'nope',
      });
      await settle();

      expect(seen.whereType<WsErrorBadCommand>(), hasLength(1));
      expect(socket.subscribedChatIds, contains(chatId));
    });
  });
}
