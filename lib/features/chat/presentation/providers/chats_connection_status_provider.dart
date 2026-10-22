import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/network/connectivity_providers.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

/// What the chats list says in place of its title while it is not simply
/// up to date. Nothing at all is the usual answer.
enum ChatsConnectionStatus {
  /// No network link, or a socket that has given up: nothing the app can
  /// hurry, so nothing is drawn as work in progress.
  waitingForNetwork,

  /// The socket is on its way up.
  connecting,

  /// Connected, and the list is fetching what it missed while it was not —
  /// opened from the device's copy, or back from a dropped connection.
  updating;

  /// Whether the app is busy with it, rather than waiting on the outside.
  bool get isWorking => this != waitingForNetwork;
}

/// The status for a socket in [socket], with or without [hasNetworkLink],
/// and a list that [isCatchingUp] or not.
///
/// The same split `ChatConnectionStrip` makes inside a chat: no link, or a
/// socket that stopped trying, is the reader's network; anything short of
/// `ready` is the app's own work.
ChatsConnectionStatus? chatsConnectionStatusOf({
  required ChatSocketStatus socket,
  required bool hasNetworkLink,
  required bool isCatchingUp,
}) {
  if (!hasNetworkLink) return ChatsConnectionStatus.waitingForNetwork;

  return switch (socket) {
    ChatSocketStatus.disconnected => ChatsConnectionStatus.waitingForNetwork,
    ChatSocketStatus.connecting ||
    ChatSocketStatus.reconnecting => ChatsConnectionStatus.connecting,
    ChatSocketStatus.ready =>
      isCatchingUp ? ChatsConnectionStatus.updating : null,
  };
}

final chatsConnectionStatusProvider = Provider<ChatsConnectionStatus?>(
  (ref) {
    return chatsConnectionStatusOf(
      socket: ref.watch(chatSocketStateProvider),
      hasNetworkLink: ref.watch(hasNetworkLinkProvider),
      isCatchingUp: ref.watch(
        chatListProvider.select((list) => list.value?.isCatchingUp ?? false),
      ),
    );
  },
  dependencies: [
    chatSocketStateProvider,
    hasNetworkLinkProvider,
    chatListProvider,
  ],
);
