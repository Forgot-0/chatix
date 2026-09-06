import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/models/message_model.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_realtime_merge.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

const _pageSize = 50;

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

  bool get canLoadMore => hasNext && (nextChatId != null || nextDate != null);

  int get totalUnread =>
      items.fold(0, (sum, chat) => sum + (chat.unreadCount ?? 0));

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

class ChatListController extends AsyncNotifier<ChatListState> {
  StreamSubscription<WSEvent>? _eventSubscription;

  final Set<String> _inFlightChatFetches = <String>{};

  @override
  Future<ChatListState> build() async {
    ref.onDispose(() {
      _eventSubscription?.cancel();
      _eventSubscription = null;
    });

    final loaded = await _fetchFirstPage();
    _attachRealtime();
    return loaded;
  }

  void _attachRealtime() {
    _eventSubscription = ref
        .read(chatSocketServiceProvider)
        .events
        .listen(
          _onEvent,
          onError: (Object error, StackTrace stackTrace) {
            Logger.error('ChatList: event stream error', error, stackTrace);
          },
          cancelOnError: false,
        );
  }

  Future<void> _onEvent(WSEvent event) async {
    switch (event) {
      case NewMessage():
        await _onNewMessage(event);

      case MessagesRead():
        _onMessagesRead(event);

      case ChatUpdated():
        _patchRow(
          event.chatId,
          (chat) => ChatRealtimeMerge.applyChatUpdated(
            chat,
            name: event.name,
            description: event.description,
            isPublic: event.isPublic,
            adminOnly: event.adminOnly,
            slowModeSeconds: event.slowModeSeconds,
            permissions: event.permissions,
            reactionsMode: event.reactionsMode == null
                ? null
                : ChatReactionsMode.fromWire(event.reactionsMode),
            allowedReactions: event.allowedReactions,
          ),
        );

      case ChatCreated():
        await _onChatCreated(event);

      case ChatDeleted():
        _mutate(
          (s) => s.copyWith(
            items: ChatRealtimeMerge.removeChat(s.items, event.chatId),
            nextDate: s.nextDate,
            nextChatId: s.nextChatId,
          ),
        );

      case MemberJoined():
        _mutate(
          (s) => s.copyWith(
            items: ChatRealtimeMerge.adjustMemberCount(
              s.items,
              event.chatId,
              1,
            ),
            nextDate: s.nextDate,
            nextChatId: s.nextChatId,
          ),
        );

      case MemberLeft():
        _onMembershipChange(event.chatId, event.userId, removed: true);

      case MemberKick():
        _onMembershipChange(event.chatId, event.targetUserId, removed: true);

      case MemberBanned():
        if (event.ban) {
          _onMembershipChange(event.chatId, event.targetUserId, removed: true);
        } else {
          await _onUnbanned(event.chatId, event.targetUserId);
        }

      case MessageEdited():
      case MessageDeleted():
        break;

      case AttachmentSuccess():
        break;

      case WsHistory():
        break;

      case ReactionUpdated():
        break;

      case WsReady():
      case WsSubscribed():
      case WsUnsubscribed():
      case WsPing():
      case WsPong():
      case WsErrorBadCommand():
      case WsErrorNotChatMember():
      case WsAuthInvalid():
      case WsUnimplementedEvent():
      case WsUnknown():
        break;
    }
  }

  Future<void> _onNewMessage(NewMessage event) async {
    final message = _decodeMessage(event.message);
    if (message == null) return;

    final myUserId = ref.read(authProvider).value?.id;

    final isOpen = ref
        .read(chatSocketServiceProvider)
        .subscribedChatIds
        .contains(event.chatId);

    _mutate((s) {
      final index = s.items.indexWhere((c) => c.id == event.chatId);
      if (index < 0) return s;

      final updated = ChatRealtimeMerge.applyNewMessageToRow(
        s.items[index],
        message,
        ts: event.ts,
        isOpen: isOpen,
        isOwn: myUserId != null && message.authorId == myUserId,
      );

      final items = [...s.items]..[index] = updated;

      return s.copyWith(
        items: ChatRealtimeMerge.sortByActivity(items),
        nextDate: s.nextDate,
        nextChatId: s.nextChatId,
      );
    });
  }

  MessageEntity? _decodeMessage(Map<String, dynamic> raw) {
    try {
      return MessageModel.fromJson(raw).toEntity();
    } catch (error) {
      Logger.warning('ChatList: bad message payload: $error');
      return null;
    }
  }

  Future<void> _onChatCreated(ChatCreated event) async {
    final current = state.value;
    if (current == null) return;
    if (current.items.any((c) => c.id == event.chatId)) return;
    if (!_inFlightChatFetches.add(event.chatId)) return;

    try {
      final result = await ref
          .read(getChatUseCaseProvider)
          .execute(event.chatId);

      result.match(
        (failure) => Logger.warning(
          'ChatList: could not fetch created chat ${event.chatId} '
          '(${failure.message})',
        ),
        (chat) => _mutate((s) {
          if (s.items.any((c) => c.id == chat.id)) return s;
          return s.copyWith(
            items: ChatRealtimeMerge.sortByActivity([chat, ...s.items]),
            nextDate: s.nextDate,
            nextChatId: s.nextChatId,
          );
        }),
      );
    } finally {
      _inFlightChatFetches.remove(event.chatId);
    }
  }

  void _onMessagesRead(MessagesRead event) {
    final myUserId = ref.read(authProvider).value?.id;
    if (myUserId == null || event.readerId != myUserId) return;

    _patchRow(event.chatId, (chat) => chat.copyWith(unreadCount: 0));
  }

  void _onMembershipChange(
    String chatId,
    int userId, {
    required bool removed,
  }) {
    final myUserId = ref.read(authProvider).value?.id;

    if (myUserId != null && userId == myUserId && removed) {
      _mutate(
        (s) => s.copyWith(
          items: ChatRealtimeMerge.removeChat(s.items, chatId),
          nextDate: s.nextDate,
          nextChatId: s.nextChatId,
        ),
      );
      return;
    }

    _mutate(
      (s) => s.copyWith(
        items: ChatRealtimeMerge.adjustMemberCount(
          s.items,
          chatId,
          removed ? -1 : 1,
        ),
        nextDate: s.nextDate,
        nextChatId: s.nextChatId,
      ),
    );
  }

  Future<void> _onUnbanned(String chatId, int userId) async {
    final myUserId = ref.read(authProvider).value?.id;

    if (myUserId == null || userId != myUserId) {
      _onMembershipChange(chatId, userId, removed: false);
      return;
    }

    await _refetchRow(chatId);
  }

  Future<void> _refetchRow(String chatId) async {
    if (!_inFlightChatFetches.add(chatId)) return;

    try {
      final result = await ref.read(getChatUseCaseProvider).execute(chatId);

      result.match((failure) {
        if (_isAccessDenied(failure)) {
          _mutate(
            (s) => s.copyWith(
              items: ChatRealtimeMerge.removeChat(s.items, chatId),
              nextDate: s.nextDate,
              nextChatId: s.nextChatId,
            ),
          );
        } else {
          Logger.warning(
            'ChatList: membership refresh for $chatId failed '
            '(${failure.message})',
          );
        }
      }, (chat) => _upsertRow(chat));
    } finally {
      _inFlightChatFetches.remove(chatId);
    }
  }

  void _upsertRow(ChatEntity chat) {
    _mutate((s) {
      final index = s.items.indexWhere((c) => c.id == chat.id);
      final items = index >= 0
          ? ([...s.items]..[index] = chat)
          : [chat, ...s.items];
      return s.copyWith(
        items: ChatRealtimeMerge.sortByActivity(items),
        nextDate: s.nextDate,
        nextChatId: s.nextChatId,
      );
    });
  }

  bool _isAccessDenied(Failure failure) {
    if (failure is! ApiFailure) return false;
    return const {
      'NOT_CHAT_MEMBER',
      'CHAT_ACCESS_DENIED',
      'NOT_FOUND_CHAT',
    }.contains(failure.code);
  }

  void _patchRow(
    String chatId,
    ChatEntity Function(ChatEntity chat) transform,
  ) {
    _mutate((s) {
      final index = s.items.indexWhere((c) => c.id == chatId);
      if (index < 0) return s;
      final items = [...s.items]..[index] = transform(s.items[index]);
      return s.copyWith(
        items: items,
        nextDate: s.nextDate,
        nextChatId: s.nextChatId,
      );
    });
  }

  void _mutate(ChatListState Function(ChatListState state) transform) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    final next = transform(current);
    if (next == current) return;
    state = AsyncValue.data(next);
  }

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

    final latest = state.value ?? current;

    state = result.fold(
      (failure) => AsyncValue.data(latest.copyWith(isLoadingMore: false)),
      (page) => AsyncValue.data(
        latest.copyWith(
          items: [
            ...latest.items,
            ...page.chats.where(
              (c) => !latest.items.any((existing) => existing.id == c.id),
            ),
          ],
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
