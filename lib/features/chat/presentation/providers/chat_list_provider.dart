import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/models/chat_model.dart';
import 'package:chatix/features/chat/data/models/message_model.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_realtime_merge.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

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

  /// Total unread across every loaded chat — the app-level badge.
  ///
  /// Skips rows whose `unread_count` is `null` (see [ChatEntity]: `null` means
  /// "not sent by this endpoint", not zero) and counts only what is loaded, so
  /// this is a floor rather than an exact total when the list is paginated.
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
/// [refresh] restarts from the newest, and the WebSocket subscription keeps
/// rows, ordering and unread badges live (api-docs §7).
///
/// ## What this controller listens for, and what it deliberately ignores
///
/// It watches the **same** broadcast stream as every open chat screen, but its
/// interest is almost the complement of theirs:
///
/// * `new_message` — for chats **not** on screen. Bumps the badge and floats
///   the row. Unlike before the §7.4 payload revision, the event now *does*
///   carry the full message — this still never uses its content, only
///   `MessageEntity.seq`, since the list renders no preview body.
/// * `messages_read` — previously cleared the badge when the reader was *us*;
///   now inert (see `MessagesRead`'s class doc — the payload lost `reader_id`
///   with no replacement, so this can no longer be attributed to anyone).
/// * `chat_created` / `chat_updated` / `chat_deleted` — add, patch or drop a
///   row without a full refetch.
/// * `member_*` — `member_joined` adjusts the count locally (no identity
///   needed). `member_left`/`member_kick`/`member_banned` lost the fields
///   that used to say *who*, so all three now re-fetch the chat and treat an
///   access-denied response as "it was us" — see `_refreshMembershipOrDrop`.
///
/// A `chat_created` is the one event that must fetch: the payload has the
/// chat's name and type but not `unread_count`, `me` or `last_read`, so a row
/// built from it alone would render with a broken permission state.
class ChatListController extends AsyncNotifier<ChatListState> {
  StreamSubscription<WSEvent>? _eventSubscription;

  /// Chat ids currently being (re-)fetched over REST — after a `chat_created`,
  /// or to resolve a `member_left`/`member_kick`/`member_banned` (see
  /// `_refreshMembershipOrDrop`). Guards against duplicate in-flight requests
  /// for the same chat, whichever event triggered the fetch.
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

  /// Starts folding events into the list.
  ///
  /// ⚠️ No `subscribe` call. Per-chat subscriptions are for chat *screens*;
  /// this controller relies on the events the server pushes to the connection
  /// regardless of subscription — `chat_created`, `chat_deleted` and the
  /// membership events are addressed to the user, not to a chat topic (§7.4).
  ///
  /// The honest consequence, worth stating rather than hiding: `new_message`
  /// **is** subscription-scoped, so a chat the user has not opened this session
  /// will not bump its badge live. Subscribing to all of them is not an option
  /// — `resume` caps at 20 chats (§7.3) and the list can be far longer. The
  /// badge for such a chat is therefore correct as of the last `GET /chats/`,
  /// which is what pull-to-refresh and re-entering the screen are for.
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

  /// Folds one event into the list. Exhaustive over [WSEvent] by design — a new
  /// protocol event breaks the build here until someone decides what the list
  /// should do with it.
  Future<void> _onEvent(WSEvent event) async {
    switch (event) {
      case NewMessage():
        await _onNewMessage(event);

      case MessagesRead():
        // ⚠️ Inert. `reader_id` had no replacement in the §7.4 payload
        // revision (see `MessagesRead`'s class doc), so a badge can no longer
        // be safely cleared from this event — it might be us on another
        // device, or it might be a peer, and there is no way left to tell.
        break;

      case ChatUpdated():
        _patchRow(event.chatId, (chat) {
          final updated = _decodeChat(event.chat);
          if (updated == null) return chat;
          return ChatRealtimeMerge.applyChatUpdated(chat, updated);
        });

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
        // Someone else joined a chat we can see. `member_count` is rendered on
        // the row, so it is adjusted locally rather than refetched.
        //
        // Note this can also be *us* being added to a brand-new chat without a
        // `chat_created` (an invite to an existing chat), in which case the row
        // isn't in the list yet — `_patchRow` no-ops and the chat appears on the
        // next refresh. Fetching here instead would mean a request for every
        // join in every group the user belongs to.
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
        break;
      case MemberKick():
        await _refreshMembershipOrDrop(event.chatId);

      case MemberBanned():
        // Same reasoning as above, plus: the old `ban: false` (unban) case
        // used to be a deliberate no-op here ("the next refresh brings it
        // back"). That distinction is gone too — a `member_banned` with no
        // `ban` flag could be either direction — so this now always
        // re-fetches and lets the server's answer decide: present and
        // reachable means still in, access-denied means banned.
        await _refreshMembershipOrDrop(event.chatId);

      // ── Not the list's concern ──
      case MessageEdited():
      case MessageDeleted():
        // Neither changes a row: the list shows no message preview, and an edit
        // or deletion doesn't alter the unread count (the message was already
        // counted when it arrived).
        break;

      case AttachmentSuccess():
        // Composer-side only; `confirmedAttachmentTokensProvider` owns it.
        break;

      case WsHistory():
        // Gap replay is addressed to whichever chat screen asked for it, and
        // carries message bodies this screen doesn't render.
        break;

      case ReactionUpdated():
        // Reactions never reach a list row: the preview renders
        // `ChatDTO.last_message` (§6.2), which carries no reactions field, and
        // reacting is not an unread event. The open chat's controller owns it
        // (§6.7.5).
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

  /// Badge + reordering for an incoming message — the §7.5 path for a chat
  /// that is *not* on screen.
  ///
  /// [event.message] is a full `MessageDTO` (api-docs §7.4, revised); this
  /// only reads [MessageEntity.seq]/[MessageEntity.authorId] from it — the
  /// list still renders no preview body, so there is nothing else here to
  /// decode it for.
  Future<void> _onNewMessage(NewMessage event) async {
    final message = _decodeMessage(event.message);
    if (message == null) return;

    final myUserId = ref.read(authProvider).value?.id;

    // "Open" means a `ChatDetailController` for this chat is alive, which is
    // also exactly the condition under which that controller marks the chat
    // read. Read from the socket service rather than tracked here, so there is
    // one source of truth for "which chats are on screen".
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
        // Re-sorted, not just patched: the whole point of a live list is that
        // the chat with the newest message rises to the top.
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

  ChatEntity? _decodeChat(Map<String, dynamic> raw) {
    try {
      return ChatModel.fromJson(raw).toEntity();
    } catch (error) {
      Logger.warning('ChatList: bad chat payload: $error');
      return null;
    }
  }

  /// Adds a newly created chat to the top of the list (§7.4).
  ///
  /// Still fetches the chat rather than decoding [event.chat] directly, even
  /// though that field is now a full `ChatDTO` (api-docs §7.4, revised) rather
  /// than the old name/type/member-count summary. `me` is what every
  /// permission check on the row and its screen depends on, and there is no
  /// documented guarantee that a `ChatDTO` embedded in a broadcast event is
  /// personalised per recipient — see [ChatCreated]'s class doc. A row built
  /// from an un-personalised snapshot could render with no membership and
  /// therefore no rights at all.
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

  /// The shared reaction to `member_left`/`member_kick`/`member_banned`
  /// (api-docs §7.4, revised) — see the class doc and
  /// `ChatDetailController._refreshMembershipOrLeave`, whose reasoning this
  /// mirrors for the list.
  ///
  /// Re-fetches [chatId] and treats an access-denied response as "it was us":
  /// the row is dropped. Any other outcome patches the row with the fresh
  /// chat (accurate `member_count`, permissions, etc.) — membership changed
  /// but we're still in it.
  Future<void> _refreshMembershipOrDrop(String chatId) async {
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
      }, (chat) => _patchRow(chatId, (_) => chat));
    } finally {
      _inFlightChatFetches.remove(chatId);
    }
  }

  /// Whether [failure] means "you are not, or no longer, in this chat" —
  /// the codes api-docs §6.2/§6.6 document for a chat the caller cannot see.
  bool _isAccessDenied(Failure failure) {
    if (failure is! ApiFailure) return false;
    return const {
      'NOT_CHAT_MEMBER',
      'CHAT_ACCESS_DENIED',
      'NOT_FOUND_CHAT',
    }.contains(failure.code);
  }

  /// Replaces one row in place, leaving the list untouched if the chat isn't
  /// loaded (it may simply be on a page the user hasn't scrolled to).
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

  /// See `ChatDetailController._mutate` — same two invariants: never write to a
  /// loading/errored state, never write after disposal.
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

    // Re-read: a realtime event may have changed the list while the page was
    // in flight, and folding the page into the *stale* `current` would discard
    // that update.
    final latest = state.value ?? current;

    state = result.fold(
      // Keep the pages already on screen and just drop the spinner — losing
      // a scrolled-through list because page 4 failed is far worse than the
      // missing page.
      (failure) => AsyncValue.data(latest.copyWith(isLoadingMore: false)),
      (page) => AsyncValue.data(
        latest.copyWith(
          // Filtered against what we hold: a chat that floated to the top from
          // a live `new_message` can also appear in this page, and appending it
          // blindly would show the row twice.
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
