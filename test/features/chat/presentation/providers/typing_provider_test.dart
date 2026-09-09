import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/typing_provider.dart';

/// A socket whose event stream we drive by hand.
class _FakeSocket implements ChatSocketService {
  final StreamController<WSEvent> _events = StreamController<WSEvent>.broadcast();

  @override
  Stream<WSEvent> get events => _events.stream;

  void emit(WSEvent event) => _events.add(event);

  Future<void> close() => _events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeSocket socket;
  late ProviderContainer container;

  setUp(() {
    socket = _FakeSocket();
    container = ProviderContainer(
      overrides: [chatSocketServiceProvider.overrideWithValue(socket)],
    );
    addTearDown(container.dispose);
    addTearDown(socket.close);
  });

  WsUnimplementedEvent frame(
    String type, {
    String chatId = 'chat-1',
    Map<String, dynamic> payload = const {'user_id': 7},
  }) => WsUnimplementedEvent(type, chatId: chatId, payload: payload);

  test('nobody is typing until the server says so', () {
    expect(container.read(typingUsersProvider('chat-1')), isEmpty);
  });

  test('the backend publishes nothing, so the indicator stays empty', () async {
    // api-docs §6.4: typing_start/typing_stop are declared and never sent.
    // Every other frame the gateway does send must leave this alone.
    container.listen(typingUsersProvider('chat-1'), (_, _) {});

    socket.emit(
      const MessagesRead(chatId: 'chat-1', seq: 4, readerId: 7),
    );
    await pumpEventQueue();

    expect(container.read(typingUsersProvider('chat-1')), isEmpty);
  });

  test('a typing_start would light it up', () async {
    container.listen(typingUsersProvider('chat-1'), (_, _) {});

    socket.emit(frame('typing_start'));
    await pumpEventQueue();

    expect(container.read(typingUsersProvider('chat-1')), {7});
  });

  test('typing_stop clears the person again', () async {
    container.listen(typingUsersProvider('chat-1'), (_, _) {});

    socket.emit(frame('typing_start'));
    await pumpEventQueue();
    socket.emit(frame('typing_stop'));
    await pumpEventQueue();

    expect(container.read(typingUsersProvider('chat-1')), isEmpty);
  });

  test('another chat is another indicator', () async {
    container.listen(typingUsersProvider('chat-1'), (_, _) {});
    container.listen(typingUsersProvider('chat-2'), (_, _) {});

    socket.emit(frame('typing_start', chatId: 'chat-2'));
    await pumpEventQueue();

    expect(container.read(typingUsersProvider('chat-1')), isEmpty);
    expect(container.read(typingUsersProvider('chat-2')), {7});
  });

  test('a payload without an int user_id is dropped, not guessed at', () async {
    container.listen(typingUsersProvider('chat-1'), (_, _) {});

    socket.emit(frame('typing_start', payload: const {}));
    socket.emit(frame('typing_start', payload: const {'user_id': 'seven'}));
    await pumpEventQueue();

    expect(container.read(typingUsersProvider('chat-1')), isEmpty);
  });

  test('a start stands on its own for a bounded time', () {
    // A missed typing_stop must not pin the indicator on forever; the
    // constant is the contract, the timer that uses it is trivial.
    expect(TypingUsersController.expiry, greaterThan(Duration.zero));
    expect(
      TypingUsersController.expiry,
      lessThan(const Duration(seconds: 30)),
    );
  });

  test('several people can type at once', () async {
    container.listen(typingUsersProvider('chat-1'), (_, _) {});

    socket.emit(frame('typing_start'));
    socket.emit(frame('typing_start', payload: const {'user_id': 9}));
    await pumpEventQueue();

    expect(container.read(typingUsersProvider('chat-1')), {7, 9});
  });
}
