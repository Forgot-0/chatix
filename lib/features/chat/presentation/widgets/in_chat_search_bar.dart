import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/presentation/providers/in_chat_search_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/local_search_notice.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The strip under a chat's search field: which match you are on, and the two
/// arrows that move between them.
///
/// Jumping is not a scroll. The chat asks the server for the window around
/// the match (`GET /chats/{id}/messages/context/?target_seq=`, api-docs §5.4),
/// so a match found in a preview opens at the right place in a history that
/// was never loaded.
class InChatSearchBar extends ConsumerWidget implements PreferredSizeWidget {
  const InChatSearchBar({super.key, required this.chatId});

  static const double height = 44;

  final String chatId;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final state = ref.watch(inChatSearchProvider(chatId));
    final controller = ref.read(inChatSearchProvider(chatId).notifier);

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.x4),
              child: Row(
                children: [
                  Expanded(child: _Status(state: state)),
                  IconButton(
                    tooltip: l10n.searchOlderMatch,
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: state.canGoOlder ? controller.goOlder : null,
                  ),
                  IconButton(
                    tooltip: l10n.searchNewerMatch,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: state.canGoNewer ? controller.goNewer : null,
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.state});

  final InChatSearchState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (state.isSearching) {
      return const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // Nothing typed yet: say what this search can see instead of "0 of 0".
    if (!state.hasQuery) {
      return const LocalSearchNotice(compact: true);
    }

    if (!state.hasHits) {
      return Text(
        l10n.searchNoMatches,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Row(
      children: [
        Text(
          l10n.searchMatchPosition(state.position, state.hits.length),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (state.source == MessageSearchSource.localCache) ...[
          const SizedBox(width: AppSpacing.x3),
          const Flexible(child: LocalSearchNotice(compact: true)),
        ],
      ],
    );
  }
}
