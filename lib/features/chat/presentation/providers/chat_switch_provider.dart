import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organized_chats.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/folder_selection_provider.dart';

/// The chats in the order the list draws them: the pinned zone, then the
/// rest, inside the folder the strip is on.
///
/// What Alt+↑/↓ and Ctrl+Tab walk through — the neighbours on screen, not
/// the server's order. The archive stays out of it: it is a drawer the
/// reader opens on purpose, not the next chat down.
final visibleChatOrderProvider = Provider<List<String>>((ref) {
  final chats = ref.watch(chatListProvider).value?.items ?? const [];

  final sections = organizeChats(
    chats: chats,
    context: ref.watch(chatRuleContextProvider),
    folder: ref.watch(activeChatFolderProvider),
  );

  return [for (final chat in sections.visible) chat.id];
});

/// Stepping from one chat to its neighbour in the list.
abstract final class ChatSwitching {
  /// The chat [step] rows away from [current] in [order].
  ///
  /// Stops at either end rather than wrapping round: from the last chat,
  /// "next" landing on the first one at the top reads as a jump, not a step.
  /// With no chat open — or one that is not in the list, like an archived
  /// chat — "next" starts at the top and "previous" at the bottom.
  static String? neighbour(List<String> order, String? current, int step) {
    if (order.isEmpty || step == 0) return null;

    final index = current == null ? -1 : order.indexOf(current);
    if (index < 0) return step > 0 ? order.first : order.last;

    final target = index + step;
    if (target < 0 || target >= order.length) return null;
    return order[target];
  }

  /// The chat whose pages are on top right now — the conversation itself,
  /// or its info, members or settings — or null anywhere else.
  ///
  /// Read off the router's top page rather than its URI: a chat pushed on a
  /// phone-sized window does not move the URI (go_router keeps imperative
  /// pushes out of it), but it is the top page all the same.
  static String? currentChatId(GoRouter router) =>
      _topState(router)?.pathParameters[RouteParams.chatId];

  /// The open conversation, only while it is the page on top — not while
  /// its info or member list covers it.
  static String? visibleChatId(GoRouter router) {
    final state = _topState(router);
    if (state?.name != RouteNames.chatDetail) return null;
    return state?.pathParameters[RouteParams.chatId];
  }

  static GoRouterState? _topState(GoRouter router) {
    final configuration = router.routerDelegate.currentConfiguration;
    if (configuration.isEmpty) return null;
    return router.state;
  }
}
