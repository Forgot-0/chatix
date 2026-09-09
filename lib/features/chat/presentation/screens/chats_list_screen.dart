import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:flutter/material.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_scroll_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_routes.dart';

/// Opens a chat the way the current layout wants it opened.
///
/// With one pane a chat is a place you go to and come back from, so it is
/// pushed. With two panes it is a selection in a list that is still on screen,
/// so it replaces whatever the right pane was showing instead of stacking a
/// new page behind it every time the user glances at another conversation.
void openChat(BuildContext context, String chatId) {
  final location = ChatDetailRoute(chatId).location;

  if (AppLayoutScope.of(context).isTwoPane) {
    context.go(location);
  } else {
    context.push(location);
  }
}

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

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(chatListProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chats),
        actions: [
          IconButton(
            onPressed: () => context.push(ChatSearchRoute.location),
            icon: const Icon(Icons.search),
            tooltip: l10n.searchChatsAndPeople,
          ),
        ],
      ),
      body: listState.when(
        loading: () => const AppListSkeleton(hasTrailing: true),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: l10n.chatsLoadFailed,
          onRetry: () => ref.read(chatListProvider.notifier).refresh(),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(chatListProvider.notifier).refresh(),
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
            onRefresh: () => ref.read(chatListProvider.notifier).refresh(),
            child: ListView.separated(
              key: const PageStorageKey<String>('chats-list'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.items.length + (state.canLoadMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  return const AppLoadMoreIndicator();
                }
                final chat = state.items[index];
                return ChatListTile(
                  chat: chat,
                  isSelected: chat.id == widget.selectedChatId,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(CreateChatRoute.location),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(l10n.newChat),
      ),
    );
  }
}

class ChatListTile extends ConsumerWidget {
  const ChatListTile({
    super.key,
    required this.chat,
    this.isSelected = false,
  });

  final ChatEntity chat;

  /// Whether this chat is the one open in the detail pane.
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = chat.unreadCount ?? 0;
    final l10n = AppLocalizations.of(context);
    final myUserId = ref.watch(authProvider).value?.id;

    final peer = chat.peerProfile(myUserId);

    return ListTile(
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
      selectedColor: Theme.of(context).colorScheme.onSecondaryContainer,
      leading: peer != null
          ? ChatAvatar.profile(peer)
          : ChatAvatarMosaic(
              faces: _facesOf(chat, myUserId),
              fallbackIcon: _iconFor(chat.type),
            ),
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
      onTap: () => openChat(context, chat.id),
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

  /// Faces for a group's mosaic avatar.
  ///
  /// The list endpoint does not always carry a roster, and a group that has
  /// its own `avatar_s3_key` does not need one; both cases fall through to
  /// the type icon that [ChatAvatarMosaic] draws when handed nothing.
  static List<AvatarFace> _facesOf(ChatEntity chat, int? myUserId) {
    final roster = chat.members;
    if (roster == null) return const [];

    return [
      for (final member in roster)
        if (member.userId != myUserId && member.profile != null)
          AvatarFace.profile(member.profile!),
    ];
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
