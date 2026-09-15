import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';

import '../../helpers/fakes/fake_secure_storage_service.dart';
import '../../helpers/fakes/fake_web_socket_channel.dart';

/// `resume` takes at most twenty cursors (api-docs §6.3), and the twenty-first
/// is not a polite refusal: the handler raises `MAX_LIMIT_CURSOR`, which is
/// not wrapped in `ws.error` the way the rest of that section's failures are,
/// and in practice takes the connection down. So the clamp is not a nicety —
/// it is the difference between a working socket and a loop of dropped ones.
void main() {
  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() async {
    channel = FakeWebSocketChannel();
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => channel,
    );
    await socket.connect();
  });

  tearDown(() async {
    await socket.dispose();
    await channel.dispose();
  });

  Map<String, dynamic>? lastResume() {
    for (final command in channel.commands.reversed) {
      if (command['op'] == 'resume') return command;
    }
    return null;
  }

  Map<String, int> resumedCursors() {
    final cursors = lastResume()?['cursors'];
    return cursors is Map
        ? {
            for (final entry in cursors.entries)
              entry.key as String: entry.value as int,
          }
        : const {};
  }

  test('twenty cursors go out whole', () {
    socket.resume({for (var i = 0; i < 20; i++) 'chat-$i': i + 1});

    expect(resumedCursors(), hasLength(20));
  });

  test('more than twenty are cut down to twenty', () {
    socket.resume({for (var i = 0; i < 50; i++) 'chat-$i': i + 1});

    expect(resumedCursors(), hasLength(ChatSocketService.maxResumeCursors));
  });

  test('the ones that go are the ones last opened', () {
    // Subscribing is what marks a chat as recently opened, and the most
    // recent is the one whose messages somebody is about to look at.
    for (var i = 0; i < 30; i++) {
      socket.subscribe('chat-$i', lastSeq: i + 1);
    }

    socket.resume({for (var i = 0; i < 30; i++) 'chat-$i': i + 1});

    final kept = resumedCursors().keys.toSet();
    expect(kept, hasLength(20));
    expect(kept, contains('chat-29'), reason: 'the most recently opened');
    expect(kept, isNot(contains('chat-0')), reason: 'the stalest');
  });

  test('a reconnect resumes at most twenty of what was open', () async {
    for (var i = 0; i < 30; i++) {
      socket.subscribe('chat-$i', lastSeq: i + 1);
    }

    channel.emit({
      'type': 'ws.ready',
      'payload': {
        'connection_id': 'c1',
        'gateway_id': 'g1',
        'heartbeat_interval': 30,
        'heartbeat_timeout': 75,
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(resumedCursors(), hasLength(20));
  });

  test('a chat with no cursor is still subscribed to', () async {
    // It used to be dropped outright whenever anything else had a cursor,
    // which left that chat receiving nothing for the rest of the connection.
    socket.subscribe('with-cursor', lastSeq: 5);
    socket.subscribe('no-cursor');

    channel.emit({
      'type': 'ws.ready',
      'payload': {
        'connection_id': 'c1',
        'gateway_id': 'g1',
        'heartbeat_interval': 30,
        'heartbeat_timeout': 75,
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(resumedCursors(), {'with-cursor': 5});
    expect(
      channel.commands
          .where((c) => c['op'] == 'subscribe')
          .map((c) => c['chat_id']),
      contains('no-cursor'),
    );
  });

  test('an empty resume is not sent at all', () {
    socket.resume(const {});
    expect(lastResume(), isNull);
  });
}
