import 'package:flutter/material.dart';

import 'package:chatix/core/ui/widgets/app_quick_actions.dart';

/// One of the four squares under a chat's header.
///
/// The row itself is [AppQuickActionsRow]; these names are kept because the
/// chat profile reads better with them.
typedef ChatProfileAction = AppQuickAction;

/// Call, search, notifications, media — the four things worth doing to a
/// chat from its profile, as a row of equal squares.
class ChatProfileActionsRow extends StatelessWidget {
  const ChatProfileActionsRow({super.key, required this.actions});

  final List<ChatProfileAction> actions;

  @override
  Widget build(BuildContext context) => AppQuickActionsRow(actions: actions);
}
