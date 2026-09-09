import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:flutter/material.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/core/router/app_routes.dart';

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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(chatListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            onPressed: () => context.push(ChatSearchRoute.location),
            icon: const Icon(Icons.search),
            tooltip: 'Search chats and people',
          ),
        ],
      ),
      body: listState.when(
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
              physics: const AlwaysScrollableScrollPhysics(),
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

class ChatListTile extends ConsumerWidget {
  const ChatListTile({super.key, required this.chat});

  final ChatEntity chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = chat.unreadCount ?? 0;
    final l10n = AppLocalizations.of(context);
    final myUserId = ref.watch(authProvider).value?.id;

    final peer = chat.peerProfile(myUserId);

    return ListTile(
      leading: peer != null
          ? ChatAvatar(profile: peer, userId: peer.userId)
          : CircleAvatar(child: Icon(_iconFor(chat.type))),
      title: Text(
        chatTitleOf(chat, l10n, myUserId: myUserId),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _previewOf(chat) ??
            chat.description ??
            l10n.membersCount(chat.memberCount),
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

  static String? _previewOf(ChatEntity chat) {
    final message = chat.lastMessage;
    if (message == null) return null;

    final content = message.content?.trim();
    if (content != null && content.isNotEmpty) {
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
