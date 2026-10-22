import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_scroll_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/chat/presentation/widgets/chats_list_header.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organized_chats.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/folder_selection_provider.dart';
import 'package:chatix/features/contacts/presentation/providers/blocked_users_providers.dart';
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
///
/// There is no app bar: the header ([ChatsListHeaderDelegate]) is the
/// list's first sliver, so its search pill can scroll away with the rows and
/// float back on the way up.
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

    await Future.wait([
      ref.read(chatListProvider.notifier).refresh(),
      // The archive is a second request, and a pull refreshes the screen
      // rather than one list on it. Only if it has already been fetched:
      // starting it here would make the drawer appear out of a gesture that
      // was about something else.
      if (ref.exists(archivedChatListProvider))
        ref.read(archivedChatListProvider.notifier).refresh(),
    ]);
  }

  /// Whether a scroll belongs to the list, for pull-to-refresh: the list
  /// itself, or the empty and error states, which scroll inside its last
  /// sliver. Not the folder strip, which scrolls sideways in the header.
  static bool _isListScroll(ScrollNotification notification) =>
      notification.depth == 0 ||
      (notification.depth == 1 && notification.metrics.axis == Axis.vertical);

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(chatListProvider);
    final l10n = AppLocalizations.of(context);

    // A phone gets the round button over the list's corner. Anything with a
    // rail has a pointer more often than a thumb, and the header is where a
    // pointer looks for "new".
    final hasFab = AppLayoutScope.of(context).usesBottomBar;

    final organizer = ref.watch(organizerDataProvider);
    final showFolders =
        organizer.folders.isNotEmpty && !organizer.settings.foldersHidden;

    final header = ChatsListHeaderDelegate(
      topInset: MediaQuery.paddingOf(context).top,
      showFolders: showFolders,
      showNewChat: !hasFab,
    );

    return Scaffold(
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: RefreshIndicator(
          onRefresh: _refresh,
          // Out from under the header, which is fully open whenever a pull
          // can start.
          edgeOffset: header.maxExtent,
          notificationPredicate: _isListScroll,
          child: CustomScrollView(
            key: const PageStorageKey<String>('chats-list'),
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                floating: true,
                delegate: header,
              ),
              ...listState.when(
                loading: () => const [
                  SliverFillRemaining(
                    child: AppListSkeleton(hasTrailing: true),
                  ),
                ],
                error: (error, _) => [
                  SliverFillRemaining(
                    child: AppErrorState(
                      error: error,
                      fallbackMessage: l10n.chatsLoadFailed,
                      onRetry: _refresh,
                    ),
                  ),
                ],
                data: (state) => _contentSlivers(state, hasFab: hasFab),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: hasFab
          ? FloatingActionButton(
              onPressed: () => context.push(CreateChatRoute.location),
              tooltip: l10n.newChat,
              shape: const CircleBorder(),
              child: const Icon(Icons.edit_outlined),
            )
          : null,
    );
  }

  /// The rows under the header, or what stands in for them.
  List<Widget> _contentSlivers(ChatListState state, {required bool hasFab}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final folder = ref.watch(activeChatFolderProvider);

    final sections = organizeChats(
      chats: state.items,
      context: ref.watch(chatRuleContextProvider),
      folder: folder,
    );

    // The archive is its own request with its own cursor (api-docs §5.2), so
    // the drawer is not a slice of this list — it is a second one, fetched
    // whether or not it is open, because the header has to say how much is
    // in there.
    final archive = ref.watch(archivedChatListProvider).value;
    final archived = archive?.items ?? const <ChatEntity>[];

    if (state.items.isEmpty && archived.isEmpty) {
      return [
        SliverFillRemaining(
          child: AppEmptyState(
            illustration: AppIllustrationKind.conversations,
            title: l10n.noChatsYet,
            message: l10n.noChatsYetHint,
            action: FilledButton.icon(
              onPressed: () => context.push(CreateChatRoute.location),
              icon: const Icon(Icons.add_comment_outlined),
              label: Text(l10n.newChat),
            ),
          ),
        ),
      ];
    }

    return [
      if (archived.isNotEmpty)
        SliverToBoxAdapter(
          child: _ArchiveHeader(
            count: archived.length,
            unread: unreadInArchive(
              archived,
              quiet: ref.watch(blockedDirectChatIdsProvider),
            ),
            isOpen: _archiveOpen,
            onTap: () => setState(() => _archiveOpen = !_archiveOpen),
          ),
        ),
      if (archived.isNotEmpty && _archiveOpen)
        _rows(archived, state: archive!, isLast: false),
      if (archived.isNotEmpty && _archiveOpen && archive!.canLoadMore)
        SliverToBoxAdapter(
          child: Center(
            child: TextButton(
              onPressed: () =>
                  ref.read(archivedChatListProvider.notifier).loadMore(),
              child: Text(l10n.showMore),
            ),
          ),
        ),

      // The pinned block keeps a ground of its own and no heading: the shade
      // says these rows are not part of the stream below them, and each row
      // carries its own pin.
      if (sections.pinned.isNotEmpty)
        DecoratedSliver(
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer),
          sliver: _rows(sections.pinned, state: state, isLast: true),
        ),

      if (sections.active.isNotEmpty)
        _rows(sections.active, state: state, isLast: true),
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
        SliverToBoxAdapter(
          child: SizedBox(
            height: hasFab
                ? ChatsListLayout.fabClearance
                : ChatsListLayout.endPadding,
          ),
        ),
    ];
  }

  /// One block of rows, hairline-separated the way a list of people is —
  /// the rule starts where the text does, so the avatars form a column.
  Widget _rows(
    List<ChatEntity> chats, {
    required ChatListState state,
    required bool isLast,
  }) {
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
              isSelected: chat.id == widget.selectedChatId,
              peerReadSeq: state.peerReadSeqOf(chat.id),
            ),
            if (!isBlockEnd || !isLast) const Divider(height: 1, indent: 80),
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
