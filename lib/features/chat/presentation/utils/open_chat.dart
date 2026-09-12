import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/chat/presentation/providers/search_history_provider.dart';

/// Opens a chat the way the current layout wants it opened.
///
/// With one pane a chat is a place you go to and come back from, so it is
/// pushed. With two panes it is a selection in a list that is still on screen,
/// so it replaces whatever the right pane was showing instead of stacking a
/// new page behind it every time the user glances at another conversation.
///
/// Going through here is also what makes a chat "recent": the search screen
/// offers the last few opened chats when the field is empty, and this is the
/// one place that knows someone chose one.
void openChat(
  BuildContext context,
  WidgetRef ref,
  String chatId, {
  int? messageSeq,
}) {
  ref.read(searchHistoryProvider.notifier).rememberChat(chatId);

  final location = ChatDetailRoute(chatId, messageSeq: messageSeq).location;

  if (AppLayoutScope.of(context).isTwoPane) {
    context.go(location);
  } else {
    context.push(location);
  }
}
