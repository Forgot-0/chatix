import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/chat/presentation/providers/typing_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_header_status.dart';
import 'package:chatix/features/chat/presentation/utils/chat_menu_actions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_header_menu.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/chat/presentation/widgets/typing_dots.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

String _typingLabel(AppLocalizations l10n, ChatEntity? chat, Set<int> typing) {
  if (typing.length == 1) {
    final name = chat?.membershipOf(typing.first)?.profile?.bestName;
    if (name != null && name.isNotEmpty) return l10n.userTyping(name);
  }
  return l10n.severalTyping(typing.length);
}

/// The app bar's title block: who the conversation is with, and what they are
/// doing right now.
///
/// The line under the name is [ChatHeaderStatus]: "online" for a person who
/// is, the member count and how many of them are here for a group, the
/// audience for a channel. Presence is a member-list request (api-docs §5.3)
/// and nothing pushes changes to it, so it is asked for when the header
/// appears and again once [MemberPresenceCache.ttl] has passed, for as long
/// as it stays up.
class ChatHeaderTitle extends ConsumerStatefulWidget {
  const ChatHeaderTitle({
    super.key,
    required this.chatId,
    required this.chat,
    required this.myUserId,
    required this.onTap,
  });

  final String chatId;
  final ChatEntity? chat;
  final int? myUserId;
  final VoidCallback? onTap;

  @override
  ConsumerState<ChatHeaderTitle> createState() => _ChatHeaderTitleState();
}

class _ChatHeaderTitleState extends ConsumerState<ChatHeaderTitle> {
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    _requestPresence();
    // Several looks per lifetime of an answer: a tick on the TTL itself would
    // land a moment before the answer it was meant to replace expires, and
    // skip it, doubling the wait. The cache decides whether a look is a
    // request.
    _presenceTimer = Timer.periodic(
      MemberPresenceCache.ttl ~/ 3,
      (_) => _requestPresence(),
    );
  }

  @override
  void didUpdateWidget(covariant ChatHeaderTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The chat arrives after the header when it was opened by link, and a
    // header can be handed a different chat in two-pane mode.
    if (oldWidget.chatId != widget.chatId ||
        oldWidget.chat?.type != widget.chat?.type) {
      _requestPresence();
    }
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    super.dispose();
  }

  /// Asks the cache, which decides whether that turns into a request.
  void _requestPresence() {
    switch (widget.chat?.type) {
      case ChatType.direct:
        ref.read(chatPresenceProvider.notifier).ensureFresh(widget.chatId);
      case ChatType.group:
      case ChatType.supergroup:
        ref.read(chatOnlineCountProvider.notifier).ensureFresh(widget.chatId);
      case ChatType.channel:
      case null:
        // A channel's audience is a number, not a crowd: nobody is "here".
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final current = widget.chat;

    // Empty until the gateway starts publishing typing_start/typing_stop —
    // it declares both and sends neither (api-docs §6.4). Nothing else in
    // the header fakes activity while that is the case.
    final typing = ref.watch(typingUsersProvider(widget.chatId));

    if (current == null) {
      return Text(l10n.chatFallbackTitle, style: theme.textTheme.titleMedium);
    }

    final title = watchChatTitle(ref, current, l10n, myUserId: widget.myUserId);
    final status = ChatHeaderStatus.of(
      current,
      peerOnline: current.type == ChatType.direct
          ? ref.watch(chatPeerOnlineProvider(widget.chatId))
          : null,
      membersOnline:
          current.type == ChatType.group || current.type == ChatType.supergroup
          ? ref.watch(chatMembersOnlineProvider(widget.chatId))
          : null,
    );

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2,
          vertical: AppSpacing.x1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Every kind of chat has a face here — the person, the group's
            // mosaic, the channel's initial — drawn exactly as its row in
            // the list draws it, and flying up into the profile header
            // when the title is tapped.
            Hero(
              tag: chatAvatarHeroTag(widget.chatId),
              flightShuttleBuilder: chatAvatarHeroFlight,
              child: ChatRowAvatar(
                chat: current,
                myUserId: widget.myUserId,
                size: ChatAvatarSize.md,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (typing.isNotEmpty)
                    TypingIndicator(label: _typingLabel(l10n, current, typing))
                  else if (status != null)
                    Text(
                      status.label(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: status.isAccent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The buttons at the end of a chat's app bar: a call, where there is anyone
/// to call, and the menu with everything else.
///
/// Search lives in the menu rather than beside it, and the member list is
/// reached through the chat's profile — two buttons fewer, and none that
/// means nothing in the chat it is drawn in.
class ChatHeaderActions extends StatelessWidget {
  const ChatHeaderActions({
    super.key,
    required this.chat,
    required this.me,
    required this.onSearch,
    required this.onSelectMessages,
  });

  final ChatEntity chat;
  final ChatMemberEntity? me;
  final VoidCallback onSearch;
  final VoidCallback onSelectMessages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (chatCallAvailable(chat, me))
          IconButton(
            tooltip: l10n.callTitle,
            icon: const Icon(Icons.call_outlined),
            onPressed: () => context.push(ChatCallRoute.locationOf(chat.id)),
          ),
        ChatHeaderMenuButton(
          chat: chat,
          me: me,
          onSearch: onSearch,
          onSelectMessages: onSelectMessages,
        ),
      ],
    );
  }
}
