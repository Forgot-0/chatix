import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_routes.dart';

/// Opens a chat the way the current layout wants it opened.
///
/// With one pane a chat is a place you go to and come back from, so it is
/// pushed. With two panes it is a selection in a list that is still on screen,
/// so it replaces whatever the right pane was showing instead of stacking a
/// new page behind it every time the user glances at another conversation.
void openChat(BuildContext context, String chatId) {
  final location = ChatDetailRoute(chatId).location;

  if (AppLayoutScope.of(context).isTwoPane) {
    context.go(location);
  } else {
    context.push(location);
  }
}
