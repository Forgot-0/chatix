import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

const _pageSize = 50;

/// `GET /chats/` list state — the chats accumulated so far plus the **cursor**
/// for the next request.
///
/// ⚠️ Unlike `ProjectListState`/`ProfileListState`, there is no `page` number
/// here and [hasNext] is not derived from anything — both come from the
/// server's cursor envelope (api-docs §1.6). The cursor is the *pair*
/// [nextDate] + [nextChatId], carried verbatim from the last response.
class ChatListState extends Equatable {
  final List<ChatEntity> items;
  final bool hasNext;
  final String? nextDate;
  final String? nextChatId;
  final bool isLoadingMore;

  const ChatListState({
    this.items = const [],
    this.hasNext = false,
    this.nextDate,
    this.nextChatId,
    this.isLoadingMore = false,
  });

  /// Mirrors [ChatsPage.canLoadMore]: a `has_next: true` with no cursor would
  /// otherwise spin the scroll listener forever.
  bool get canLoadMore => hasNext && (nextChatId != null || nextDate != null);

  ChatListState copyWith({
    List<ChatEntity>? items,
    bool? hasNext,
    String? nextDate,
    String? nextChatId,
    bool? isLoadingMore,
  }) {
    return ChatListState(
      items: items ?? this.items,
      hasNext: hasNext ?? this.hasNext,
      // Cursors are replaced wholesale (including back to null when a page
      // ends the list), so they are NOT `?? this.x` — a stale cursor would
      // silently re-read the same window.
      nextDate: nextDate,
      nextChatId: nextChatId,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    items,
    hasNext,
    nextDate,
    nextChatId,
    isLoadingMore,
  ];
}

/// Drives `ChatsListScreen`: [loadMore] appends the next cursor page,
/// [refresh] restarts from the newest.
///
/// Live updates (a new message bumping a chat to the top, unread counts
/// changing) arrive over the WebSocket layer, api-docs §7 — not modelled here.
/// Until then [refresh] is the only way the list changes, which is why the
/// screen offers pull-to-refresh.
class ChatListController extends AsyncNotifier<ChatListState> {
  @override
  Future<ChatListState> build() => _fetchFirstPage();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchFirstPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.canLoadMore || current.isLoadingMore) {
      return;
    }

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final result = await ref
        .read(getChatsUseCaseProvider)
        .executeNextPage(
          ChatsPage(
            chats: const [],
            hasNext: current.hasNext,
            nextDate: current.nextDate,
            nextChatId: current.nextChatId,
          ),
          limit: _pageSize,
        );

    state = result.fold(
      // Keep the pages already on screen and just drop the spinner — losing
      // a scrolled-through list because page 4 failed is far worse than the
      // missing page.
      (failure) => AsyncValue.data(current.copyWith(isLoadingMore: false)),
      (page) => AsyncValue.data(
        current.copyWith(
          items: [...current.items, ...page.chats],
          hasNext: page.hasNext,
          nextDate: page.nextDate,
          nextChatId: page.nextChatId,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<ChatListState> _fetchFirstPage() async {
    final result = await ref
        .read(getChatsUseCaseProvider)
        .execute(limit: _pageSize);
    return result.fold((failure) => throw failure, (page) {
      return ChatListState(
        items: page.chats,
        hasNext: page.hasNext,
        nextDate: page.nextDate,
        nextChatId: page.nextChatId,
      );
    });
  }
}

final chatListProvider =
    AsyncNotifierProvider<ChatListController, ChatListState>(
      ChatListController.new,
    );
