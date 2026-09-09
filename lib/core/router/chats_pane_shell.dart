import 'package:flutter/material.dart';

import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The chats branch's body — one pane, or two.
///
/// Below [AppBreakpoints.expanded] this is a pass-through: the branch's own
/// navigator stacks the list and the open chat as usual. At and above it the
/// list moves out of the navigator and onto the left, and the navigator — still
/// holding the chat, its members, its info — becomes the right pane.
///
/// The open chat is identified by the URL, not by a field somewhere, which is
/// what makes it survive a rotation: the layout flips, the location does not,
/// so the same chat is on screen before and after.
class ChatsPaneShell extends StatelessWidget {
  const ChatsPaneShell({
    super.key,
    required this.selectedChatId,
    required this.child,
  });

  /// The chat the location points at, or null on `/chats` itself.
  final String? selectedChatId;

  /// The branch navigator: the chat and anything pushed on top of it.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppLayoutScope.of(context).isTwoPane) return child;

    return Row(
      children: [
        SizedBox(
          width: AppBreakpoints.listPaneWidth,
          child: ChatsListScreen(selectedChatId: selectedChatId),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: child),
      ],
    );
  }
}

/// What `/chats` itself renders.
///
/// On a phone that is the list. In two-pane mode the list is already on the
/// left, drawn by [ChatsPaneShell], so this page — which is what the right pane
/// shows until a chat is picked — becomes the placeholder instead. Only one of
/// the two is ever mounted, and both put the same [PageStorageKey] on their
/// scrollable, so the list's scroll offset carries across a rotation.
class ChatsListPane extends StatelessWidget {
  const ChatsListPane({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLayoutScope.of(context).isTwoPane
        ? const NoChatSelectedPane()
        : const ChatsListScreen();
  }
}

/// The right pane before a chat is picked.
class NoChatSelectedPane extends StatelessWidget {
  const NoChatSelectedPane({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: AppEmptyState(
        icon: Icons.forum_outlined,
        title: l10n.noChatSelected,
        message: l10n.noChatSelectedHint,
      ),
    );
  }
}
