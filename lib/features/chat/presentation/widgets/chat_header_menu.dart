import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_state_failures.dart';
import 'package:chatix/features/chat/presentation/providers/chat_profile_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_state_actions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_exit_flow.dart';
import 'package:chatix/features/chat/presentation/utils/chat_menu_actions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_mute_options.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/features/contacts/presentation/providers/blocked_users_providers.dart';
import 'package:chatix/features/contacts/presentation/widgets/block_actions.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The "⋮" of an open chat.
///
/// What it offers is [chatMenuActionsFor]'s call; this draws it, and carries
/// out whatever is picked. Silencing asks "for how long" in a second menu
/// opened in the same place, rather than a cascade that would not fit beside
/// the first one on a phone.
class ChatHeaderMenuButton extends ConsumerWidget {
  const ChatHeaderMenuButton({
    super.key,
    required this.chat,
    required this.me,
    required this.onSearch,
    required this.onSelectMessages,
  });

  final ChatEntity chat;
  final ChatMemberEntity? me;

  /// The search field lives in the chat screen's app bar, as does the
  /// selection: both are the screen's to open.
  final VoidCallback onSearch;
  final VoidCallback onSelectMessages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pinned, archived, silenced are the list row's (api-docs §5.2); the
    // detail response this chat was loaded from does not carry them.
    final state = ref.watch(chatRowStateProvider(chat.id));

    final myUserId = ref.watch(authProvider.select((user) => user.value?.id));
    final peerId = chat.peerUserId(myUserId);
    final peerBlocked = peerId == null
        ? null
        : ref.watch(isUserBlockedProvider(peerId));

    return Builder(
      builder: (buttonContext) => IconButton(
        tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
        icon: const Icon(Icons.more_vert),
        onPressed: () => _open(
          buttonContext,
          ref,
          chatMenuActionsFor(chat, me, state: state, peerBlocked: peerBlocked),
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    List<ChatMenuAction> actions,
  ) async {
    final l10n = AppLocalizations.of(context);
    final position = _anchorOf(context);

    // Leaving and deleting sit under a rule, apart from what is undone as
    // easily as it is done.
    final firstDestructive = actions.indexWhere((it) => it.isDestructive);

    final picked = await showMenu<ChatMenuAction>(
      context: context,
      position: position,
      constraints: _constraints,
      items: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i == firstDestructive && i > 0) const PopupMenuDivider(),
          PopupMenuItem<ChatMenuAction>(
            value: actions[i],
            child: ChatMenuEntry(
              icon: _iconOf(actions[i]),
              label: _labelOf(actions[i], l10n),
              destructive: actions[i].isDestructive,
            ),
          ),
        ],
      ],
    );
    if (picked == null || !context.mounted) return;

    await _run(context, ref, picked, position);
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    ChatMenuAction action,
    RelativeRect position,
  ) async {
    final l10n = AppLocalizations.of(context);
    final actions = ref.read(chatStateActionsProvider);

    switch (action) {
      case ChatMenuAction.search:
        onSearch();
      case ChatMenuAction.selectMessages:
        onSelectMessages();
      case ChatMenuAction.mute:
        final option = await _pickMuteOption(context, position);
        if (option == null || !context.mounted) return;
        final failure = await actions.setMuted(
          chat.id,
          muted: true,
          until: option.untilFrom(DateTime.now()),
        );
        if (!context.mounted) return;
        _report(context, failure, done: l10n.chatMutedToast);
      case ChatMenuAction.unmute:
        final failure = await actions.setMuted(chat.id, muted: false);
        if (!context.mounted) return;
        _report(context, failure, done: l10n.chatUnmutedToast);
      case ChatMenuAction.pin:
      case ChatMenuAction.unpin:
        final pinned = action == ChatMenuAction.pin;
        final failure = await actions.setPinned(chat.id, pinned: pinned);
        if (!context.mounted) return;
        _report(
          context,
          failure,
          done: pinned ? l10n.chatPinnedToast : l10n.chatUnpinnedToast,
        );
      case ChatMenuAction.archive:
        final failure = await actions.setArchived(chat.id, archived: true);
        if (!context.mounted) return;
        if (failure != null) {
          _reportFailure(context, failure);
          return;
        }
        // The chat stays open — archiving tidies the list, it does not
        // close the conversation — and the way back is one tap away.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.chatArchivedToast),
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () => actions.setArchived(chat.id, archived: false),
              ),
            ),
          );
      case ChatMenuAction.unarchive:
        final failure = await actions.setArchived(chat.id, archived: false);
        if (!context.mounted) return;
        _report(context, failure, done: l10n.chatUnarchivedToast);
      case ChatMenuAction.manage:
        await context.push(ChatSettingsRoute.locationOf(chat.id));
      case ChatMenuAction.block:
      case ChatMenuAction.unblock:
        final myUserId = ref.read(authProvider).value?.id;
        final peerId = chat.peerUserId(myUserId);
        if (peerId == null) return;
        final name = chatTitleOf(
          chat,
          l10n,
          myUserId: myUserId,
          peerLocalName: readPeerLocalName(ref, chat, myUserId),
        );
        if (action == ChatMenuAction.block) {
          await BlockActions.block(context, ref, userId: peerId, name: name);
        } else {
          await BlockActions.unblock(context, ref, userId: peerId, name: name);
        }
      case ChatMenuAction.leave:
        await ChatExitFlow.run(context, ref, chat: chat, exit: ChatExit.leave);
      case ChatMenuAction.delete:
        await ChatExitFlow.run(context, ref, chat: chat, exit: ChatExit.delete);
    }
  }

  Future<ChatMuteOption?> _pickMuteOption(
    BuildContext context,
    RelativeRect position,
  ) {
    final l10n = AppLocalizations.of(context);

    return showMenu<ChatMuteOption>(
      context: context,
      position: position,
      constraints: _constraints,
      items: [
        PopupMenuItem<ChatMuteOption>(
          enabled: false,
          child: ChatMenuHeading(label: l10n.chatMenuMute),
        ),
        for (final option in ChatMuteOption.values)
          PopupMenuItem<ChatMuteOption>(
            value: option,
            child: ChatMenuEntry(
              icon: option == ChatMuteOption.forever
                  ? Icons.notifications_off_outlined
                  : Icons.schedule,
              label: option.label(l10n),
            ),
          ),
      ],
    );
  }

  /// Says how it went: quietly when it worked, in the reader's words when it
  /// did not.
  void _report(BuildContext context, Failure? failure, {required String done}) {
    if (failure == null) {
      AppSnackbar.quiet(context, done);
      return;
    }
    _reportFailure(context, failure);
  }

  void _reportFailure(BuildContext context, Failure failure) {
    final l10n = AppLocalizations.of(context);

    AppSnackbar.failure(
      context,
      failure is PinnedChatsLimitFailure
          ? l10n.pinLimitReached(failure.limit)
          : friendlyFailureMessage(
              failure,
              l10n: l10n,
              fallback: l10n.errorOccurred,
            ),
    );
  }

  static const BoxConstraints _constraints = BoxConstraints(
    minWidth: AppMenuSizes.minWidth,
    maxWidth: AppMenuSizes.maxWidth,
  );

  /// Under the button, its right edge on the button's right edge.
  static RelativeRect _anchorOf(BuildContext context) {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final below = Offset(0, button.size.height);

    return RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(below, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero) + below,
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
  }

  IconData _iconOf(ChatMenuAction action) => switch (action) {
    ChatMenuAction.search => Icons.search,
    ChatMenuAction.mute => Icons.notifications_off_outlined,
    ChatMenuAction.unmute => Icons.notifications_active_outlined,
    ChatMenuAction.pin => Icons.push_pin_outlined,
    ChatMenuAction.unpin => Icons.push_pin,
    ChatMenuAction.archive => Icons.archive_outlined,
    ChatMenuAction.unarchive => Icons.unarchive_outlined,
    ChatMenuAction.selectMessages => Icons.check_circle_outline,
    ChatMenuAction.manage => Icons.settings_outlined,
    ChatMenuAction.block => Icons.block,
    ChatMenuAction.unblock => Icons.lock_open_outlined,
    ChatMenuAction.leave => Icons.logout,
    ChatMenuAction.delete => Icons.delete_outline,
  };

  String _labelOf(ChatMenuAction action, AppLocalizations l10n) =>
      switch (action) {
        ChatMenuAction.search => l10n.chatMenuSearch,
        ChatMenuAction.mute => l10n.chatMenuMute,
        ChatMenuAction.unmute => l10n.chatMenuUnmute,
        ChatMenuAction.pin => l10n.chatMenuPin,
        ChatMenuAction.unpin => l10n.chatMenuUnpin,
        ChatMenuAction.archive => l10n.archiveChat,
        ChatMenuAction.unarchive => l10n.unarchiveChat,
        ChatMenuAction.selectMessages => l10n.selectMessages,
        ChatMenuAction.manage =>
          chat.type == ChatType.channel ? l10n.manageChannel : l10n.manageGroup,
        ChatMenuAction.block => l10n.blockUserAction,
        ChatMenuAction.unblock => l10n.unblockUserAction,
        ChatMenuAction.leave => chatExitLabel(ChatExit.leave, chat.type, l10n),
        ChatMenuAction.delete => chatExitLabel(
          ChatExit.delete,
          chat.type,
          l10n,
        ),
      };
}

/// One line of a chat menu: a glyph and what it does.
class ChatMenuEntry extends StatelessWidget {
  const ChatMenuEntry({
    super.key,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;

  /// Leaving and deleting: drawn in the error colour, glyph and all.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return Row(
      children: [
        Icon(
          icon,
          size: AppMenuSizes.iconSize,
          color: destructive ? color : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppMenuSizes.iconGap),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// The title over a second-level menu, saying what its choices are for.
class ChatMenuHeading extends StatelessWidget {
  const ChatMenuHeading({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
      ),
    );
  }
}
