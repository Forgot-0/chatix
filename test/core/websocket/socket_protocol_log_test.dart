import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/core/websocket/socket_protocol_log.dart';

import '../../helpers/fakes/fake_secure_storage_service.dart';
import '../../helpers/fakes/fake_web_socket_channel.dart';

/// What went wrong on somebody else's phone is a sequence of frames, and none
/// of it is visible in the UI. This is how that sequence gets off the device
/// — while staying off by default, because recording puts message text in a
/// buffer.
void main() {
  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  group('the buffer', () {
    test('records nothing while it is switched off', () {
      final log = SocketProtocolLog();

      log.record(SocketFrameDirection.inbound, '{"type":"ws.pong"}');
      log.note('connected');

      expect(log.isEmpty, isTrue);
      expect(log.dump(), 'No WebSocket frames recorded.');
    });

    test('records both directions once it is on', () {
      final log = SocketProtocolLog()..enabled = true;

      log.record(SocketFrameDirection.outbound, '{"op":"ping"}');
      log.record(SocketFrameDirection.inbound, '{"type":"ws.pong"}');

      expect(log.dump(), contains('-> {"op":"ping"}'));
      expect(log.dump(), contains('<- {"type":"ws.pong"}'));
    });

    test('keeps the newest lines and drops the oldest', () {
      final log = SocketProtocolLog(capacity: 3)..enabled = true;

      for (var i = 0; i < 6; i++) {
        log.note('line $i');
      }

      expect(log.length, 3);
      expect(log.dump(), contains('line 5'));
      expect(log.dump(), isNot(contains('line 0')));
    });

    test('a huge frame is cut rather than allowed to fill the window', () {
      // A page of history is tens of kilobytes and would push everything
      // that explains it out of the buffer.
      final log = SocketProtocolLog(capacity: 10, maxFrameLength: 20)
        ..enabled = true;

      log.record(SocketFrameDirection.inbound, 'x' * 500);

      final line = log.entries.single.text;
      expect(line, contains('500 chars'));
      expect(line.length, lessThan(60));
    });

    test('switching it off and clearing leaves nothing behind', () {
      final log = SocketProtocolLog()..enabled = true;
      log.note('something');

      log
        ..enabled = false
        ..clear();

      expect(log.isEmpty, isTrue);
    });
  });

  group('wired to the socket', () {
    late FakeWebSocketChannel channel;
    late SocketProtocolLog log;
    late ChatSocketService socket;

    setUp(() {
      channel = FakeWebSocketChannel();
      log = SocketProtocolLog();
      socket = ChatSocketService(
        secureStorage: FakeSecureStorageService(
          initialValues: {AppConstants.accessTokenKey: 'super-secret-token'},
        ),
        protocolLog: log,
        channelFactory: (_) => channel,
      );
    });

    tearDown(() async {
      await socket.dispose();
      await channel.dispose();
    });

    test('captures the conversation in both directions', () async {
      log.enabled = true;
      await socket.connect();

      socket.subscribe('c1', lastSeq: 4);
      channel.emit({'type': 'ws.pong', 'payload': const <String, dynamic>{}});
      await Future<void>.delayed(Duration.zero);

      final dump = log.dump();
      expect(dump, contains('connecting to'));
      expect(dump, contains('"op":"subscribe"'));
      expect(dump, contains('ws.pong'));
    });

    test('never writes the token down', () async {
      // The dump is meant to be handed to somebody else, and the token is in
      // the connect URL (api-docs §6.1).
      log.enabled = true;
      await socket.connect();

      expect(log.dump(), isNot(contains('super-secret-token')));
      // Percent-encoded, because it went through `Uri`.
      expect(log.dump(), contains('redacted'));
    });

    test('records the close code, which is the whole diagnosis', () async {
      log.enabled = true;
      await socket.connect();

      channel.serverClose(1012, 'connection limit exceeded');
      await Future<void>.delayed(Duration.zero);

      expect(log.dump(), contains('code 1012'));
    });

    test('a socket with recording off leaves no trace', () async {
      await socket.connect();
      socket.subscribe('c1', lastSeq: 4);
      await Future<void>.delayed(Duration.zero);

      expect(log.isEmpty, isTrue);
    });
  });
}
