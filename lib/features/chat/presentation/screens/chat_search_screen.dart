import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_search.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_search_provider.dart';
import 'package:chatix/features/chat/presentation/providers/search_history_provider.dart';
import 'package:chatix/features/chat/presentation/utils/direct_chat_lookup.dart';
import 'package:chatix/features/chat/presentation/utils/open_chat.dart';
import 'package:chatix/features/chat/presentation/widgets/local_search_notice.dart';
import 'package:chatix/features/chat/presentation/widgets/search_result_tiles.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One field, three things to look in.
///
/// The three tabs are not three variations of one search: chats and messages
/// are answered from what this device holds, because `GET /chats/` has no
/// search parameter and the API has no message search at all (api-docs §5.2,
/// §5.4), while people come from `GET /profiles/`, which does. The messages
/// tab says as much rather than letting a reader assume the whole history was
/// looked through.
class ChatSearchScreen extends ConsumerStatefulWidget {
  const ChatSearchScreen({super.key});

  @override
  ConsumerState<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends ConsumerState<ChatSearchScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _isStartingChat = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(searchQueryProvider);
    final tab = ref.watch(searchTabProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: ref.read(searchQueryProvider.notifier).type,
          onSubmitted: ref.read(searchQueryProvider.notifier).submit,
          decoration: InputDecoration(
            hintText: l10n.searchEverything,
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: l10n.clear,
              icon: const Icon(Icons.close),
              onPressed: _clear,
            ),
        ],
        bottom: query.isEmpty ? null : const _SearchTabs(),
      ),
      body: query.isEmpty
          ? _SearchStart(onPickQuery: _useQuery, onOpenChat: _openChat)
          : switch (tab) {
              SearchTab.chats => _ChatResults(
                query: query,
                onOpen: _openChat,
              ),
              SearchTab.people => _PeopleResults(
                query: query,
                isBusy: _isStartingChat,
                onOpen: _openPerson,
              ),
              SearchTab.messages => _MessageResults(
                query: query,
                onOpen: _openMessage,
              ),
            },
    );
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).submit('');
    setState(() {});
  }

  /// Runs a search someone picked out of their history.
  void _useQuery(String query) {
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);

    ref.read(searchQueryProvider.notifier).submit(query);
    setState(() {});
  }

  void _openChat(String chatId) {
    _remember();
    openChat(context, ref, chatId);
  }

  void _openMessage(MessageSearchHit hit) {
    _remember();
    openChat(context, ref, hit.chatId, messageSeq: hit.seq);
  }

  /// A search someone acted on is worth offering again next time.
  void _remember() {
    ref
        .read(searchHistoryProvider.notifier)
        .rememberQuery(ref.read(searchQueryProvider));
  }

  Future<void> _openPerson(ProfileEntity profile) async {
    if (_isStartingChat) return;

    _remember();

    // Dedup before creating: the backend never raises DIRECT_CHAT_EXISTS, so a
    // second create would silently make a duplicate 1:1 chat (api-docs §5.2).
    final existing = findDirectChatWith(
      ref.read(chatListProvider).value?.items ?? const [],
      profile.id,
      myUserId: ref.read(authProvider).value?.id,
    );
    if (existing != null) {
      openChat(context, ref, existing.id);
      return;
    }

    setState(() => _isStartingChat = true);

    final result = await ref
        .read(createChatUseCaseProvider)
        .execute(chatType: ChatType.direct, memberIds: [profile.id]);

    if (!mounted) return;
    setState(() => _isStartingChat = false);

    result.match(
      (failure) {
        final existingChatId = existingDirectChatId(failure);
        if (existingChatId != null) {
          ref.read(chatListProvider.notifier).refresh();
          context.pushReplacement(ChatDetailRoute(existingChatId).location);
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chatFailureMessage(failure) ??
                  friendlyFailureMessage(
                    failure,
                    fallback: AppLocalizations.of(context).startChatFailed,
                  ),
            ),
          ),
        );
      },
      (chat) {
        ref.read(chatListProvider.notifier).refresh();
        context.pushReplacement(ChatDetailRoute(chat.id).location);
      },
    );
  }
}

/// Chats / People / Messages, under the field.
class _SearchTabs extends ConsumerWidget implements PreferredSizeWidget {
  const _SearchTabs();

  static const double height = 46;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = ref.watch(searchTabProvider);

    String labelOf(SearchTab tab) => switch (tab) {
      SearchTab.chats => l10n.chats,
      SearchTab.people => l10n.searchPeople,
      SearchTab.messages => l10n.searchTabMessages,
    };

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                for (final tab in SearchTab.values)
                  Expanded(
                    child: _SearchTabButton(
                      label: labelOf(tab),
                      isSelected: tab == selected,
                      onTap: () =>
                          ref.read(searchTabProvider.notifier).select(tab),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }
}

class _SearchTabButton extends StatelessWidget {
  const _SearchTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x2,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
          if (isSelected)
            Container(height: 2, color: scheme.primary),
        ],
      ),
    );
  }
}

/// What an empty field shows: what was searched before, and what was opened.
class _SearchStart extends ConsumerWidget {
  const _SearchStart({required this.onPickQuery, required this.onOpenChat});

  final ValueChanged<String> onPickQuery;
  final ValueChanged<String> onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(searchHistoryProvider);

    final chats = ref.watch(chatListProvider).value?.items ?? const [];
    final recent = <ChatEntity>[
      for (final id in history.chatIds)
        ...chats.where((chat) => chat.id == id).take(1),
    ];

    if (history.queries.isEmpty && recent.isEmpty) {
      return AppEmptyState(
        icon: Icons.search,
        title: l10n.searchStartTitle,
        message: l10n.searchStartHint,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.x8),
      children: [
        if (history.queries.isNotEmpty) ...[
          _SectionHeader(
            title: l10n.searchRecentQueries,
            action: TextButton(
              onPressed: ref.read(searchHistoryProvider.notifier).clearQueries,
              child: Text(l10n.searchClearHistory),
            ),
          ),
          for (final query in history.queries)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(query),
              onTap: () => onPickQuery(query),
              trailing: IconButton(
                tooltip: l10n.searchRemoveFromHistory,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => ref
                    .read(searchHistoryProvider.notifier)
                    .removeQuery(query),
              ),
            ),
        ],
        if (recent.isNotEmpty) ...[
          _SectionHeader(title: l10n.searchRecentChats),
          for (final chat in recent)
            ChatSearchResultTile(
              hit: ChatSearchHit.plain(chat),
              query: '',
              onTap: () => onOpenChat(chat.id),
            ),
        ],
      ],
    );
  }
}

class _ChatResults extends ConsumerWidget {
  const _ChatResults({required this.query, required this.onOpen});

  final String query;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hits = ref.watch(chatSearchResultsProvider);

    if (hits.isEmpty) {
      return AppEmptyState(
        icon: Icons.forum_outlined,
        title: l10n.noChatsFound,
        message: l10n.noChatsFoundHint,
      );
    }

    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (context, index) {
        final hit = hits[index];
        return ChatSearchResultTile(
          key: ValueKey<String>('chat-hit-${hit.chat.id}'),
          hit: hit,
          query: query,
          onTap: () => onOpen(hit.chat.id),
        );
      },
    );
  }
}

class _PeopleResults extends ConsumerStatefulWidget {
  const _PeopleResults({
    required this.query,
    required this.isBusy,
    required this.onOpen,
  });

  final String query;
  final bool isBusy;
  final ValueChanged<ProfileEntity> onOpen;

  @override
  ConsumerState<_PeopleResults> createState() => _PeopleResultsState();
}

class _PeopleResultsState extends ConsumerState<_PeopleResults> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(peopleSearchProvider(widget.query).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(peopleSearchProvider(widget.query));

    return results.when(
      loading: () => const AppListSkeleton(),
      error: (error, _) => AppErrorState(
        error: error,
        fallbackMessage: l10n.peopleSearchFailed,
        onRetry: () => ref.invalidate(peopleSearchProvider(widget.query)),
      ),
      data: (state) {
        if (state.isEmpty) {
          return AppEmptyState(
            icon: Icons.person_search_outlined,
            title: l10n.noPeopleFound,
            message: l10n.noPeopleFoundHint,
          );
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: state.people.length + (state.hasNext ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.people.length) {
              return const AppLoadMoreIndicator();
            }

            final profile = state.people[index];
            return PersonSearchResultTile(
              key: ValueKey<int>(profile.id),
              profile: profile,
              query: widget.query,
              onTap: widget.isBusy ? null : () => widget.onOpen(profile),
            );
          },
        );
      },
    );
  }
}

class _MessageResults extends ConsumerWidget {
  const _MessageResults({required this.query, required this.onOpen});

  final String query;
  final ValueChanged<MessageSearchHit> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(messageSearchProvider(query));
    final chats = ref.watch(chatListProvider).value?.items ?? const [];

    ChatEntity? chatOf(String chatId) {
      for (final chat in chats) {
        if (chat.id == chatId) return chat;
      }
      return null;
    }

    return results.when(
      loading: () => const AppListSkeleton(),
      error: (error, _) => AppErrorState(
        error: error,
        fallbackMessage: l10n.messageSearchFailed,
        onRetry: () => ref.invalidate(messageSearchProvider(query)),
      ),
      data: (result) {
        final isLocal = result.source == MessageSearchSource.localCache;

        if (result.isEmpty) {
          // A column rather than a list: the empty state sizes itself to the
          // room it is given, and a scroll view gives it none.
          return Column(
            children: [
              if (isLocal) const LocalSearchNotice(),
              Expanded(
                child: AppEmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: l10n.noMessagesFound,
                  message: isLocal ? l10n.searchLoadedHistoryExplained : null,
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          itemCount: result.hits.length + (isLocal ? 1 : 0) + 1,
          itemBuilder: (context, index) {
            if (isLocal && index == 0) return const LocalSearchNotice();

            final hitIndex = isLocal ? index - 1 : index;
            if (hitIndex >= result.hits.length) {
              return result.isCapped
                  ? _CappedNotice(count: result.hits.length)
                  : const SizedBox(height: AppSpacing.x8);
            }

            final hit = result.hits[hitIndex];
            return MessageSearchResultTile(
              key: ValueKey<String>('message-hit-${hit.message.id}'),
              hit: hit,
              query: query,
              chat: chatOf(hit.chatId),
              onTap: () => onOpen(hit),
            );
          },
        );
      },
    );
  }
}

class _CappedNotice extends StatelessWidget {
  const _CappedNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x8,
      ),
      child: Text(
        AppLocalizations.of(context).searchResultsCapped(count),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailing = action;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x4,
        trailing == null ? AppSpacing.x4 : AppSpacing.x2,
        AppSpacing.x1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
