import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/network/connectivity_providers.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chats_connection_status_provider.dart';

class _FakeChatListController extends ChatListController {
  _FakeChatListController(this._state);

  final ChatListState _state;

  @override
  Future<ChatListState> build() async => _state;
}

/// What the chats list says in place of its title: the reader's network,
/// the app's own work, or nothing.
void main() {
  ChatsConnectionStatus? statusOf(
    ChatSocketStatus socket, {
    bool hasNetworkLink = true,
    bool isCatchingUp = false,
  }) => chatsConnectionStatusOf(
    socket: socket,
    hasNetworkLink: hasNetworkLink,
    isCatchingUp: isCatchingUp,
  );

  test('a ready socket and a current list say nothing', () {
    expect(statusOf(ChatSocketStatus.ready), isNull);
  });

  test('a socket on its way up is connecting', () {
    expect(
      statusOf(ChatSocketStatus.connecting),
      ChatsConnectionStatus.connecting,
    );
    expect(
      statusOf(ChatSocketStatus.reconnecting),
      ChatsConnectionStatus.connecting,
    );
  });

  test('no network link at all is waiting, whatever the socket says', () {
    for (final socket in ChatSocketStatus.values) {
      expect(
        statusOf(socket, hasNetworkLink: false),
        ChatsConnectionStatus.waitingForNetwork,
        reason: '$socket',
      );
    }
  });

  test('a socket that stopped trying is waiting too', () {
    expect(
      statusOf(ChatSocketStatus.disconnected),
      ChatsConnectionStatus.waitingForNetwork,
    );
  });

  test('connected and catching up is updating', () {
    expect(
      statusOf(ChatSocketStatus.ready, isCatchingUp: true),
      ChatsConnectionStatus.updating,
    );
  });

  test('catching up does not hide that the socket is still down', () {
    expect(
      statusOf(ChatSocketStatus.reconnecting, isCatchingUp: true),
      ChatsConnectionStatus.connecting,
    );
  });

  test('only waiting is not the app at work', () {
    expect(ChatsConnectionStatus.waitingForNetwork.isWorking, isFalse);
    expect(ChatsConnectionStatus.connecting.isWorking, isTrue);
    expect(ChatsConnectionStatus.updating.isWorking, isTrue);
  });

  test('the provider reads the list it is about', () async {
    final container = ProviderContainer(
      overrides: [
        chatSocketStateProvider.overrideWithValue(ChatSocketStatus.ready),
        hasNetworkLinkProvider.overrideWithValue(true),
        chatListProvider.overrideWith(
          () =>
              _FakeChatListController(const ChatListState(isCatchingUp: true)),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.listen(chatsConnectionStatusProvider, (_, _) {});
    await container.read(chatListProvider.future);

    expect(
      container.read(chatsConnectionStatusProvider),
      ChatsConnectionStatus.updating,
    );
  });
}
