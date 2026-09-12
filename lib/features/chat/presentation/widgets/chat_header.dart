import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/typing_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
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
class ChatHeaderTitle extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final current = chat;

    // Empty until the gateway starts publishing typing_start/typing_stop —
    // it declares both and sends neither (api-docs §6.4). Nothing else in
    // the header fakes activity while that is the case.
    final typing = ref.watch(typingUsersProvider(chatId));

    if (current == null) {
      return Text(l10n.chatFallbackTitle, style: theme.textTheme.titleMedium);
    }

    final peer = current.peerProfile(myUserId);
    final title = chatTitleOf(current, l10n, myUserId: myUserId);

    final subtitle = current.type == ChatType.direct
        ? peer?.username?.trim().isNotEmpty == true
              ? '@${peer!.username!.trim()}'
              : null
        : l10n.membersCount(current.memberCount);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (peer != null) ChatAvatar.profile(peer),
            if (peer != null) const SizedBox(width: 10),
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
                  else if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
