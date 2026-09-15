import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/core/websocket/socket_token_source.dart';
import 'package:chatix/core/websocket/ws_event.dart';

import '../../helpers/fakes/fake_secure_storage_service.dart';
import '../../helpers/fakes/fake_web_socket_channel.dart';

/// Hands out a new token every time, and remembers how it was asked.
class _RecordingTokenSource implements SocketTokenSource {
  _RecordingTokenSource({this.answers});

  /// Tokens to hand out in order; null entries mean "the session is over".
  final List<String?>? answers;

  final List<bool> calls = [];

  int _issued = 0;

  @override
  Future<String?> token({bool forceRefresh = false}) async {
    calls.add(forceRefresh);

    final scripted = answers;
    if (scripted != null) {
      final index = calls.length - 1;
      return index < scripted.length ? scripted[index] : scripted.last;
    }

    _issued++;
    return 'token-$_issued';
  }
}

/// Close codes are the socket's entire error vocabulary, and the three that
/// matter mean three different things (api-docs §6.2, §6.5): 1001 is a
/// heartbeat we missed, 1008 is a token the gateway would not take, and 1012
/// is a third device on the account displacing the oldest connection — which
/// is not an error and not the reader's business.
void main() {
  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  late List<FakeWebSocketChannel> channels;
  late List<Uri> connects;
  late _RecordingTokenSource tokens;
  late ChatSocketService socket;

  /// A fresh channel per connect, so a reconnect is a new socket the way it
  /// is in life.
  FakeWebSocketChannel open(Uri uri) {
    connects.add(uri);
    final channel = FakeWebSocketChannel();
    channels.add(channel);
    return channel;
  }

  void build({List<String?>? answers}) {
    channels = [];
    connects = [];
    tokens = _RecordingTokenSource(answers: answers);
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'stored-token'},
      ),
      tokenSource: tokens,
      channelFactory: open,
    );
  }

  tearDown(() async {
    await socket.dispose();
    for (final channel in channels) {
      await channel.dispose();
    }
  });

  void ready(FakeWebSocketChannel channel) {
    channel.emit({
      'type': 'ws.ready',
      'payload': {
        'connection_id': 'c1',
        'gateway_id': 'g1',
        'heartbeat_interval': 30,
        'heartbeat_timeout': 75,
      },
    });
  }

  /// Long enough for the first backoff step plus its jitter.
  Future<void> waitForReconnect() =>
      Future<void>.delayed(const Duration(milliseconds: 1600));

  test('the connect URL carries a token asked for at connect time', () async {
    build();
    await socket.connect();

    expect(tokens.calls, [false]);
    expect(connects.single.queryParameters['token'], 'token-1');
  });

  test('a reconnect asks again rather than reusing the first token', () async {
    // Five minutes of life (api-docs §0) is less than some outages last.
    build();
    await socket.connect();
    channels.first.serverClose(1006);
    await waitForReconnect();

    expect(connects, hasLength(2));
    expect(connects.last.queryParameters['token'], 'token-2');
  });

  group('1008 — the token would not do', () {
    test('renews the token and comes back', () async {
      build();
      await socket.connect();
      ready(channels.first);

      channels.first.serverClose(1008, 'invalid token');
      await waitForReconnect();

      expect(tokens.calls, [false, true], reason: 'the second is forced');
      expect(connects, hasLength(2));
      expect(socket.isTokenInvalid.value, isFalse);
    });

    test('does not announce the session as over on the first one', () async {
      build();
      final seen = <WSEvent>[];
      socket.events.listen(seen.add);

      await socket.connect();
      channels.first.serverClose(1008);
      await waitForReconnect();

      expect(seen.whereType<WsAuthInvalid>(), isEmpty);
    });

    test('gives up when the renewed token is refused too', () async {
      build();
      final seen = <WSEvent>[];
      socket.events.listen(seen.add);

      await socket.connect();
      channels.first.serverClose(1008);
      await waitForReconnect();

      expect(connects, hasLength(2));
      channels.last.serverClose(1008);
      await Future<void>.delayed(Duration.zero);

      expect(seen.whereType<WsAuthInvalid>(), hasLength(1));
      expect(socket.isTokenInvalid.value, isTrue);
      expect(connects, hasLength(2), reason: 'no third attempt');
    });

    test('a session that cannot be renewed at all is over', () async {
      build(answers: [null]);
      final seen = <WSEvent>[];
      socket.events.listen(seen.add);

      await socket.connect();
      await Future<void>.delayed(Duration.zero);

      expect(connects, isEmpty);
      expect(seen.whereType<WsAuthInvalid>(), hasLength(1));
    });

    test('a good connection forgives the earlier refusal', () async {
      // Otherwise one expired token early in a long session would make the
      // next 1008, hours later, terminal.
      build();
      await socket.connect();
      channels.first.serverClose(1008);
      await waitForReconnect();

      ready(channels.last);
      await Future<void>.delayed(Duration.zero);

      channels.last.serverClose(1008);
      await waitForReconnect();

      expect(connects, hasLength(3), reason: 'the streak was reset by ready');
    });
  });

  test('1001 — a missed heartbeat is an ordinary reconnect', () async {
    build();
    final seen = <WSEvent>[];
    socket.events.listen(seen.add);

    await socket.connect();
    channels.first.serverClose(1001, 'heartbeat timeout');
    await waitForReconnect();

    expect(connects, hasLength(2));
    expect(tokens.calls, [false, false], reason: 'the token was never refused');
    expect(seen.whereType<WsAuthInvalid>(), isEmpty);
  });

  test('1012 — the connection limit is nobody\'s problem', () async {
    // A third device displaced the oldest connection (api-docs §6.2). Come
    // back quietly; the reader never needed to know.
    build();
    final seen = <WSEvent>[];
    socket.events.listen(seen.add);

    await socket.connect();
    channels.first.serverClose(1012, 'connection limit exceeded');
    await waitForReconnect();

    expect(connects, hasLength(2));
    expect(seen.whereType<WsAuthInvalid>(), isEmpty);
    expect(socket.isTokenInvalid.value, isFalse);
  });

  test('an intentional close stays closed', () async {
    build();
    await socket.connect();
    await socket.disconnect();
    await waitForReconnect();

    expect(connects, hasLength(1));
  });
}
