import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_store.dart';
import 'package:chatix/features/chat/data/datasources/chat_socket_cursor_store.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

/// `resume` after a reconnect is only as good as the `last_seq` it carries
/// (api-docs §6.3). Keeping the cursors on disk is what makes that true of a
/// reconnect that happens to be a whole app restart.
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';

  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  late ChatLocalStore store;

  setUp(() => store = inMemoryChatLocalStore());

  Future<void> remember(String chat, int seq) => store.writeReadState(
    ChatReadState(
      chatId: chat,
      lastSeq: seq,
      reportedSeq: 0,
      updatedAt: DateTime.utc(2026),
    ),
  );

  test('reads back every chat it knows a cursor for', () async {
    await remember(chatId, 42);
    await remember('other', 7);

    expect(ChatCacheSocketCursorStore(store).load(), {chatId: 42, 'other': 7});
  });

  test('a chat with no cursor is not offered one', () async {
    await remember(chatId, 0);
    expect(ChatCacheSocketCursorStore(store).load(), isEmpty);
  });

  test('a cursor never moves backwards', () async {
    final cursors = ChatCacheSocketCursorStore(store);

    cursors.save(chatId, 40);
    await Future<void>.delayed(Duration.zero);
    cursors.save(chatId, 12);
    await Future<void>.delayed(Duration.zero);

    expect(cursors.load()[chatId], 40);
  });

  test('a stored cursor reaches the next handshake', () async {
    // The app was killed at seq 42. The connection it makes at the next
    // start asks the gateway to resume from there, so the messages that
    // arrived in between are replayed instead of missed.
    await remember(chatId, 42);

    final channel = FakeWebSocketChannel();
    addTearDown(channel.dispose);

    Uri? connectUri;
    final socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      cursorStore: ChatCacheSocketCursorStore(store),
      channelFactory: (uri) {
        connectUri = uri;
        return channel;
      },
    );
    addTearDown(socket.dispose);

    expect(socket.cursors[chatId], 42);

    socket.subscribe(chatId);
    await socket.connect();

    expect(connectUri?.queryParameters['initial_last_seq'], '42');
  });

  test('what the socket learns is written down', () async {
    final channel = FakeWebSocketChannel();
    addTearDown(channel.dispose);

    final socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      cursorStore: ChatCacheSocketCursorStore(store),
      channelFactory: (_) => channel,
    );
    addTearDown(socket.dispose);

    socket.subscribe(chatId, lastSeq: 91);
    await Future<void>.delayed(Duration.zero);

    expect(store.readReadState(chatId)?.lastSeq, 91);
  });
}
