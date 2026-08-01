import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';

/// `GET /chats/` 🔒 (api-docs §6.2) — the user's conversations, newest
/// activity first.
///
/// ⚠️ **Cursor** pagination, not page/offset (api-docs §1.6). There is no
/// page number and no total: the next request is driven by the
/// `(next_date, next_chat_id)` pair from the previous response, and `has_next`
/// is a field the server sends rather than something computed here. That is
/// also why the infinite scroll can only ever move forward — there is no way
/// to jump to an arbitrary page.
///
/// Live updates (a chat jumping to the top on a new message, unread badges
/// changing) belong to the WebSocket layer, api-docs §7 — until then
/// pull-to-refresh is the only way this list changes.
class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key});

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  final _scrollController = ScrollController();

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
    // Pre-fetch 200 px before the end so the next page is usually already
    // there by the time the user reaches the bottom.
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(chatListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: listState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error is Failure ? error.message : 'Failed to load chats',
          onRetry: () => ref.read(chatListProvider.notifier).refresh(),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(chatListProvider.notifier).refresh(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No chats yet')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(chatListProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              // The extra row is the "loading more" spinner; it exists only
              // while the server says another page is reachable.
              itemCount: state.items.length + (state.canLoadMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return ChatListTile(chat: state.items[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppConstants.createChatRoute),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New chat'),
      ),
    );
  }
}

/// One row of the chat list.
class ChatListTile extends StatelessWidget {
  const ChatListTile({super.key, required this.chat});

  final ChatEntity chat;

  @override
  Widget build(BuildContext context) {
    final unread = chat.unreadCount ?? 0;

    return ListTile(
      leading: CircleAvatar(child: Icon(_iconFor(chat.type))),
      title: Text(
        // A direct chat usually has no name — the backend leaves it null and
        // the client is expected to label it from the other participant.
        chat.name ?? _fallbackTitle(chat),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        chat.description ?? '${chat.memberCount} members',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (chat.lastActivityAt != null)
            Text(
              _formatTime(chat.lastActivityAt!),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          // `unread_count` is only present on ChatDTO (this list), never on
          // ChatDetaiDTO — see ChatEntity's doc table.
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Badge(label: Text('$unread')),
            ),
        ],
      ),
      onTap: () => context.push(AppConstants.chatDetailRoute(chat.id)),
    );
  }

  static IconData _iconFor(ChatType type) {
    switch (type) {
      case ChatType.direct:
        return Icons.person_outline;
      case ChatType.group:
        return Icons.group_outlined;
      case ChatType.supergroup:
        return Icons.groups_outlined;
      case ChatType.channel:
        return Icons.campaign_outlined;
    }
  }

  static String _fallbackTitle(ChatEntity chat) {
    switch (chat.type) {
      case ChatType.direct:
        return 'Direct chat';
      case ChatType.group:
        return 'Group chat';
      case ChatType.supergroup:
        return 'Supergroup';
      case ChatType.channel:
        return 'Channel';
    }
  }

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year}';
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
