import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_layout.dart';

/// Opens a place reached from the settings list the way the layout wants
/// it opened.
///
/// On one pane a section is somewhere you go and come back from, so it is
/// pushed. With two panes the list stays on screen and the section is a
/// selection in it: it replaces whatever the right pane showed instead of
/// stacking one section behind another every time the reader glances at
/// the next — the same rule `openChat` follows for conversations.
void openSettingsLocation(BuildContext context, String location) {
  if (AppLayoutScope.of(context).isTwoPane) {
    context.go(location);
  } else {
    context.push(location);
  }
}
