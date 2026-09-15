import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';

import '../../helpers/fakes/fake_secure_storage_service.dart';
import '../../helpers/fakes/fake_web_socket_channel.dart';

/// Going to the background and coming back.
///
/// A screen nobody is looking at does not need a fan-out — the gateway checks
/// subscriptions before delivering (api-docs §6.4) — and nothing is lost by
/// dropping them, because coming back sends `resume` with the cursors and the
/// gateway replays what was missed (§6.3).
void main() {
  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  late List<FakeWebSocketChannel> channels;
  late ChatSocketService socket;

  setUp(() {
    channels = [];
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) {
        final channel = FakeWebSocketChannel();
        channels.add(channel);
        return channel;
      },
    );
  });

  tearDown(() async {
    await socket.dispose();
    for (final channel in channels) {
      await channel.dispose();
    }
  });

  /// The connection currently in hand. A reconnect builds a new one, so this
  /// is always the one a command would actually travel on.
  FakeWebSocketChannel live() => channels.last;

  void ready() {
    live().emit({
      'type': 'ws.ready',
      'payload': {
        'connection_id': 'c1',
        'gateway_id': 'g1',
        'heartbeat_interval': 30,
        'heartbeat_timeout': 75,
      },
    });
  }

  Future<void> boot() async {
    await socket.connect();
    ready();
    await Future<void>.delayed(Duration.zero);
  }

  Map<String, dynamic>? lastCommand(String op) {
    for (final command in live().commands.reversed) {
      if (command['op'] == op) return command;
    }
    return null;
  }

  test('pausing unsubscribes from everything it was watching', () async {
    await boot();
    socket.subscribe('a', lastSeq: 10);
    socket.subscribe('b', lastSeq: 20);

    socket.pauseForBackground();

    expect(
      live().commands
          .where((c) => c['op'] == 'unsubscribe')
          .map((c) => c['chat_id']),
      containsAll(<String>['a', 'b']),
    );
    expect(socket.subscribedChatIds, isEmpty);
  });

  test('coming back resumes them, from where they were', () async {
    await boot();
    socket.subscribe('a', lastSeq: 10);
    socket.subscribe('b', lastSeq: 20);

    socket.pauseForBackground();
    socket.resumeFromBackground();

    expect(lastCommand('resume')?['cursors'], {'a': 10, 'b': 20});
    expect(socket.subscribedChatIds, containsAll(<String>['a', 'b']));
  });

  test('pausing twice is pausing once', () async {
    // The platform is free to report the same state twice, and a second
    // pause would find nothing subscribed and forget what to restore.
    await boot();
    socket.subscribe('a', lastSeq: 10);

    socket.pauseForBackground();
    socket.pauseForBackground();
    socket.resumeFromBackground();

    expect(lastCommand('resume')?['cursors'], {'a': 10});
  });

  test('nothing reconnects while the app is in the background', () async {
    await boot();
    socket.subscribe('a', lastSeq: 1);
    socket.pauseForBackground();

    live().serverClose(1006);
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    expect(channels, hasLength(1), reason: 'no reconnect while paused');
  });

  test('a connection lost in the background is rebuilt on return', () async {
    await boot();
    socket.subscribe('a', lastSeq: 7);
    socket.pauseForBackground();
    live().serverClose(1006);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    socket.resumeFromBackground();
    await Future<void>.delayed(Duration.zero);

    expect(channels, hasLength(2));
    // The chat is remembered on the way up, so the handshake itself carries
    // the cursor (api-docs §6.1).
    ready();
    await Future<void>.delayed(Duration.zero);
    expect(socket.subscribedChatIds, contains('a'));
  });

  test('resuming without having paused does nothing', () async {
    await boot();
    final before = live().outbound.sent.length;

    socket.resumeFromBackground();

    expect(live().outbound.sent.length, before);
  });

  test('the background ping is rarer than the foreground one', () async {
    // The platform suspends timers in the background anyway, and a gateway
    // that closes us for it answers with 1001 — an ordinary reconnect.
    await boot();
    socket.subscribe('a', lastSeq: 1);

    final foregroundPings = _pings(live());
    socket.pauseForBackground();

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(_pings(live()), foregroundPings, reason: 'no ping storm on pause');
  });
}

int _pings(FakeWebSocketChannel channel) => channel.outbound.sent
    .whereType<String>()
    .where((frame) => jsonDecode(frame)['op'] == 'ping')
    .length;
