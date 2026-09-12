import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_scroll_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organized_chats.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/folder_selection_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/widgets/folder_tabs_bar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The chats list: every conversation this account is in, most recent first.
///
/// The rows come from `GET /chats/` a page at a time, on the two-part cursor
/// the endpoint hands back (`last_activity_at` **and** `last_chat_id`,
/// api-docs §5.2) — [ChatListController] keeps both, and this screen only has
/// to ask for the next page as the bottom comes into view.
///
/// What the screen does with those rows — the pinned zone, the archive, the
/// folder the strip is on — is the chat organizer's, and none of it exists
/// on the server.
class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key, this.selectedChatId});

  /// The chat shown in the other pane, highlighted in the list. Always null
  /// in single-pane mode, where nothing is on screen beside the list.
  final String? selectedChatId;

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  late final ScrollController _scrollController = ScrollController(
    initialScrollOffset: ref.read(chatListScrollOffsetProvider),
  );

  /// The archive is a drawer inside the list rather than a screen of its own:
  /// it holds chats you chose to stop seeing, and opening it should not cost
  /// you your place in the list you were reading.
  bool _archiveOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    ref.read(chatListScrollOffsetProvider.notifier).save(position.pixels);

    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(chatListProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    // Presence answers are as stale as the rows they sit on.
    ref.read(chatPresenceProvider.notifier).invalidate();
    await ref.read(chatListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(chatListProvider);
    final l10n = AppLocalizations.of(context);

    final organizer = ref.watch(organizerDataProvider);
    final showFolders =
        organizer.folders.isNotEmpty && !organizer.settings.foldersHidden;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chats),
        actions: [
          IconButton(
            onPressed: () => context.push(ChatFoldersRoute.location),
            icon: const Icon(Icons.folder_outlined),
            tooltip: l10n.chatFolders,
          ),
          IconButton(
            onPressed: () => context.push(ChatSearchRoute.location),
            icon: const Icon(Icons.search),
            tooltip: l10n.searchChatsAndPeople,
          ),
        ],
        bottom: showFolders ? const FolderTabsBar() : null,
      ),
      body: listState.when(
        loading: () => const AppListSkeleton(hasTrailing: true),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: l10n.chatsLoadFailed,
          onRetry: _refresh,
        ),
        data: (state) => _ChatsList(
          state: state,
          selectedChatId: widget.selectedChatId,
          scrollController: _scrollController,
          archiveOpen: _archiveOpen,
          onToggleArchive: () =>
              setState(() => _archiveOpen = !_archiveOpen),
          onRefresh: _refresh,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(CreateChatRoute.location),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(l10n.newChat),
      ),
    );
  }
}

class _ChatsList extends ConsumerWidget {
  const _ChatsList({
    required this.state,
    required this.selectedChatId,
    required this.scrollController,
    required this.archiveOpen,
    required this.onToggleArchive,
    required this.onRefresh,
  });

  final ChatListState state;
  final String? selectedChatId;
  final ScrollController scrollController;
  final bool archiveOpen;
  final VoidCallback onToggleArchive;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final organizer = ref.watch(organizerDataProvider);
    final folder = ref.watch(activeChatFolderProvider);
    final muted = ref.watch(chatLocalPrefsProvider).muted;

    final sections = organizeChats(
      chats: state.items,
      organizer: organizer,
      context: ref.watch(chatRuleContextProvider),
      folder: folder,
    );

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: AppEmptyState(
          icon: Icons.forum_outlined,
          title: l10n.noChatsYet,
          message: l10n.noChatsYetHint,
          action: FilledButton.icon(
            onPressed: () => context.push(CreateChatRoute.location),
            icon: const Icon(Icons.add_comment_outlined),
            label: Text(l10n.newChat),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: const PageStorageKey<String>('chats-list'),
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (sections.hasArchive)
            SliverToBoxAdapter(
              child: _ArchiveHeader(
                count: sections.archived.length,
                unread: sections.unreadInArchive(muted),
                isOpen: archiveOpen,
                onTap: onToggleArchive,
              ),
            ),
          if (sections.hasArchive && archiveOpen)
            _rows(sections.archived, isLast: false),

          // The pinned zone is a block of its own, on its own ground: the
          // point of pinning is that those rows are not part of the stream
          // below them.
          if (sections.pinned.isNotEmpty)
            DecoratedSliver(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
              ),
              sliver: SliverMainAxisGroup(
                slivers: [
                  _SectionLabel(label: l10n.chatPinnedZone),
                  _rows(sections.pinned, isLast: true),
                  const SliverToBoxAdapter(child: SizedBox(height: 6)),
                ],
              ),
            ),

          if (sections.active.isNotEmpty)
            _rows(sections.active, isLast: true),
          if (state.canLoadMore)
            const SliverToBoxAdapter(child: AppLoadMoreIndicator()),

          if (sections.visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: folder == null
                  ? const _ArchiveOnlyNotice()
                  : const _FolderEmptyNotice(),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }

  /// One block of rows, hairline-separated the way a list of people is —
  /// the rule starts where the text does, so the avatars form a column.
  Widget _rows(List<ChatEntity> chats, {required bool isLast}) {
    return SliverList.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final isBlockEnd = index == chats.length - 1;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatListTile(
              key: ValueKey<String>(chat.id),
              chat: chat,
              isSelected: chat.id == selectedChatId,
              peerReadSeq: state.peerReadSeqOf(chat.id),
            ),
            if (!isBlockEnd || !isLast)
              const Divider(height: 1, indent: 80),
          ],
        );
      },
    );
  }
}

/// What is left when every chat has been archived: not an empty account, so
/// not the empty state — just a note that the rest is behind the lid above.
class _ArchiveOnlyNotice extends StatelessWidget {
  const _ArchiveOnlyNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.archive_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(
              l10n.allChatsArchived,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A folder whose rules nothing meets right now. Not an error, and not
/// something to fix — the folder fills itself.
class _FolderEmptyNotice extends StatelessWidget {
  const _FolderEmptyNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(
              l10n.folderEmptyChats,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              l10n.folderEmptyChatsHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x3,
          AppSpacing.x4,
          AppSpacing.x1,
        ),
        child: Row(
          children: [
            Icon(
              Icons.push_pin_outlined,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The lid on the archive: how much is in there, and whether it is open.
class _ArchiveHeader extends StatelessWidget {
  const _ArchiveHeader({
    required this.count,
    required this.unread,
    required this.isOpen,
    required this.onTap,
  });

  final int count;
  final int unread;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          onTap: onTap,
          leading: Icon(Icons.archive_outlined, color: scheme.onSurfaceVariant),
          title: Text(
            l10n.archivedChats,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(l10n.archivedChatsCount(count)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (unread > 0) ...[
                UnreadBadge(count: unread),
                const SizedBox(width: AppSpacing.x2),
              ],
              Icon(
                isOpen ? Icons.expand_less : Icons.expand_more,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
