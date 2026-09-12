import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/typography/highlighted_text.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_search.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/presentation/utils/chat_timestamp.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:chatix/features/profile/presentation/widgets/user_search_field.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A chat that matched, with the matching part picked out.
///
/// Not [ChatListTile]: a result row answers "why is this here", which means
/// showing the description a title match would never show, and it carries
/// none of the swipe actions that belong to the list itself.
class ChatSearchResultTile extends ConsumerWidget {
  const ChatSearchResultTile({
    super.key,
    required this.hit,
    required this.query,
    required this.onTap,
  });

  final ChatSearchHit hit;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final myUserId = ref.watch(authProvider.select((user) => user.value?.id));
    final title = chatTitleOf(hit.chat, l10n, myUserId: myUserId);

    return ListTile(
      onTap: onTap,
      leading: ChatRowAvatar(chat: hit.chat, myUserId: myUserId),
      title: HighlightedText(
        text: title,
        query: query,
        style: theme.textTheme.titleSmall,
        maxLines: 1,
      ),
      subtitle: _Subtitle(hit: hit, query: query, l10n: l10n, theme: theme),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.hit,
    required this.query,
    required this.l10n,
    required this.theme,
  });

  final ChatSearchHit hit;
  final String query;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // A description match needs saying: the title above it has nothing in
    // common with what was typed, and an unexplained row reads as a bug.
    if (hit.field == ChatMatchField.description) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.searchChatDescriptionMatch, style: muted),
          HighlightedText(
            text: hit.matchedText,
            query: query,
            style: muted,
            maxLines: 1,
          ),
        ],
      );
    }

    return Text(
      chatTypeLabel(hit.chat.type, l10n),
      style: muted,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Somebody from `GET /profiles/`, ready to be written to.
class PersonSearchResultTile extends StatelessWidget {
  const PersonSearchResultTile({
    super.key,
    required this.profile,
    required this.query,
    required this.onTap,
  });

  final ProfileEntity profile;
  final String query;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final specialization = profile.specialization?.trim();

    return ListTile(
      onTap: onTap,
      leading: ProfileAvatar(profile: profile, radius: 20),
      title: HighlightedText(
        text: profileLabel(profile),
        query: query,
        style: theme.textTheme.titleSmall,
        maxLines: 1,
      ),
      subtitle: specialization == null || specialization.isEmpty
          ? null
          : Text(
              specialization,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

/// One message that matched, under the chat it was said in.
class MessageSearchResultTile extends ConsumerWidget {
  const MessageSearchResultTile({
    super.key,
    required this.hit,
    required this.query,
    required this.chat,
    required this.onTap,
  });

  final MessageSearchHit hit;
  final String query;

  /// The chat the message belongs to, when the list still holds it. Null for
  /// a message cached from a chat that has since left the loaded pages.
  final ChatEntity? chat;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final myUserId = ref.watch(authProvider.select((user) => user.value?.id));
    final row = chat;

    final title = row == null
        ? l10n.searchOpenChat
        : chatTitleOf(row, l10n, myUserId: myUserId);

    final author = hit.message.profile?.bestName;

    return ListTile(
      onTap: onTap,
      leading: row == null
          ? CircleAvatar(
              backgroundColor: scheme.surfaceContainerHighest,
              child: Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            )
          : ChatRowAvatar(chat: row, myUserId: myUserId),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Text(
            formatChatTimestamp(
              hit.message.createdAt,
              l10n,
              locale: Localizations.localeOf(context).toLanguageTag(),
            ),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (author != null && author.isNotEmpty)
            Text(
              author,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          HighlightedText(
            text: hit.snippet,
            query: query,
            matchStart: hit.matchStart,
            matchLength: hit.matchLength,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
          ),
        ],
      ),
      isThreeLine: author != null && author.isNotEmpty,
    );
  }
}
