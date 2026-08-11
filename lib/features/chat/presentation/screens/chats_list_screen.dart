import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/core/router/app_routes.dart';

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
        // First fetch only: with riverpod's `skipLoadingOnRefresh`, a
        // pull-to-refresh keeps the old rows on screen instead of flashing
        // this. Trailing block on, because every real row has a timestamp
        // and possibly an unread badge there.
        loading: () => const AppListSkeleton(hasTrailing: true),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: 'Could not load your chats.',
          onRetry: () => ref.read(chatListProvider.notifier).refresh(),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(chatListProvider.notifier).refresh(),
              child: AppEmptyState(
                icon: Icons.forum_outlined,
                title: 'No chats yet',
                message: 'Start a conversation and it will show up here.',
                action: FilledButton.icon(
                  onPressed: () => context.push(CreateChatRoute.location),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('New chat'),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(chatListProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              // Keeps pull-to-refresh reachable when a short list doesn't
              // fill the viewport.
              physics: const AlwaysScrollableScrollPhysics(),
              // The extra row is the "loading more" spinner; it exists only
              // while the server says another page is reachable.
              itemCount: state.items.length + (state.canLoadMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  return const AppLoadMoreIndicator();
                }
                return ChatListTile(chat: state.items[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(CreateChatRoute.location),
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
        // Preview precedence, richest first:
        //   1. `last_message` — what Telegram shows and what api-docs §6.2
        //      added `ChatDTO.last_message` for.
        //   2. the chat's own `description` — the previous source. NOT
        //      removed: it is a real `ChatDTO` field, it is the only subtitle
        //      a chat with no messages yet can show, and `GET /chats/{id}/`
        //      (`ChatDetailDTO`) sends a description but never a last message,
        //      so a `ChatListTile` built from a detail response would lose its
        //      subtitle entirely if this fallback were dropped.
        //   3. the member count, as before.
        _previewOf(chat) ?? chat.description ?? '${chat.memberCount} members',
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
          // ChatDetailDTO — see ChatEntity's doc table.
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Badge(label: Text('$unread')),
            ),
        ],
      ),
      onTap: () => context.push(ChatDetailRoute(chat.id).location),
    );
  }

  /// One-line preview of [ChatEntity.lastMessage], or `null` when there is
  /// nothing worth showing.
  ///
  /// An attachment-only message has `content: null` (a legitimate value, not
  /// missing data — api-docs §6.4), so it is labelled by its type instead of
  /// rendering as a blank subtitle. Deleted messages arrive as `system`, whose
  /// content the backend writes itself, so it is shown verbatim.
  static String? _previewOf(ChatEntity chat) {
    final message = chat.lastMessage;
    if (message == null) return null;

    final content = message.content?.trim();
    if (content != null && content.isNotEmpty) {
      // The sender's name is only useful where more than one person can post.
      if (chat.type == ChatType.direct || message.type == MessageType.system) {
        return content;
      }
      return '${message.authorLabel}: $content';
    }

    final label = switch (message.type) {
      MessageType.image => '📷 Photo',
      MessageType.file => '📎 File',
      MessageType.voice => '🎤 Voice message',
      MessageType.videoNote => '📹 Video message',
      MessageType.system => null,
      MessageType.text || MessageType.reply || MessageType.forward =>
        message.attachments.isEmpty ? null : '📎 Attachment',
    };
    if (label == null) return null;

    return chat.type == ChatType.direct
        ? label
        : '${message.authorLabel}: $label';
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
