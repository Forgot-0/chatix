import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/models/message_model.dart';
import 'package:chatix/features/chat/data/models/reaction_model.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_members_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_realtime_merge.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

const _pageSize = 30;
const _uuid = Uuid();

class PendingMessage extends Equatable {
  final String idempotencyKey;

  final String? content;
  final String? replyToId;
  final List<String> uploadTokens;

  final MessageType? messageType;

  final Failure? failure;

  const PendingMessage({
    required this.idempotencyKey,
    this.content,
    this.replyToId,
    this.uploadTokens = const [],
    this.messageType,
    this.failure,
  });

  PendingMessage copyWith({Failure? failure, bool clearFailure = false}) {
    return PendingMessage(
      idempotencyKey: idempotencyKey,
      content: content,
      replyToId: replyToId,
      uploadTokens: uploadTokens,
      messageType: messageType,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
    idempotencyKey,
    content,
    replyToId,
    uploadTokens,
    messageType,
    failure,
  ];
}

class ChatDetailState extends Equatable {
  final ChatEntity? chat;

  final List<MessageEntity> messages;

  final int? nextCursor;
  final bool hasNext;
  final bool isLoadingMore;

  final List<PendingMessage> pending;

  final MessageEntity? replyTo;

  final int? myUserId;

  final bool isGone;

  final Map<int, int> peerReadSeq;

  final String? highlightMessageId;

  final bool isViewingHistory;

  /// The gateway refused our subscribe: messages already loaded still show, but
  /// nothing new will arrive until the chat is reopened.
  final bool isRealtimeRejected;

  const ChatDetailState({
    this.chat,
    this.messages = const [],
    this.nextCursor,
    this.hasNext = false,
    this.isLoadingMore = false,
    this.pending = const [],
    this.replyTo,
    this.myUserId,
    this.isGone = false,
    this.peerReadSeq = const {},
    this.highlightMessageId,
    this.isViewingHistory = false,
    this.isRealtimeRejected = false,
  });

  bool get canLoadMore => hasNext && nextCursor != null;

  MessageReactionsEntity reactionsFor(String messageId) {
    for (final message in messages) {
      if (message.id == messageId) return message.reactionSummary;
    }
    return MessageReactionsEntity.empty(messageId);
  }

  /// How far the other side has read, or null when nobody has told us.
  ///
  /// `messages_read` carries `{ seq, reader_id }` (api-docs §6.4), so this is
  /// the furthest seq reported by anyone who is not me. Null is "unknown",
  /// which is not the same as "unread" — the ticks depend on the difference.
  int? get peerReadCursor {
    int? furthest;
    for (final entry in peerReadSeq.entries) {
      if (entry.key == myUserId) continue;
      if (furthest == null || entry.value > furthest) furthest = entry.value;
    }
    return furthest;
  }

  bool isReadByPeer(MessageEntity message) {
    if (chat?.type != ChatType.direct) return false;
    final cursor = peerReadCursor;
    return cursor != null && cursor >= message.seq;
  }

  ChatMemberEntity? get me {
    final id = myUserId;
    if (id == null) return chat?.me;
    return chat?.membershipOf(id);
  }

  ChatDetailState copyWith({
    ChatEntity? chat,
    List<MessageEntity>? messages,
    int? nextCursor,
    bool? hasNext,
    bool? isLoadingMore,
    List<PendingMessage>? pending,
    MessageEntity? replyTo,
    bool clearReplyTo = false,
    int? myUserId,
    bool? isGone,
    Map<int, int>? peerReadSeq,
    String? highlightMessageId,
    bool clearHighlight = false,
    bool? isViewingHistory,
    bool? isRealtimeRejected,
  }) {
    return ChatDetailState(
      chat: chat ?? this.chat,
      messages: messages ?? this.messages,
      myUserId: myUserId ?? this.myUserId,
      nextCursor: nextCursor,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pending: pending ?? this.pending,
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
      isGone: isGone ?? this.isGone,
      peerReadSeq: peerReadSeq ?? this.peerReadSeq,
      highlightMessageId: clearHighlight
          ? null
          : (highlightMessageId ?? this.highlightMessageId),
      isViewingHistory: isViewingHistory ?? this.isViewingHistory,
      isRealtimeRejected: isRealtimeRejected ?? this.isRealtimeRejected,
    );
  }

  @override
  List<Object?> get props => [
    chat,
    messages,
    nextCursor,
    hasNext,
    isLoadingMore,
    pending,
    replyTo,
    myUserId,
    isGone,
    peerReadSeq,
    highlightMessageId,
    isViewingHistory,
    isRealtimeRejected,
  ];
}

class ChatDetailController extends AsyncNotifier<ChatDetailState> {
  ChatDetailController(this._chatId);

  final String _chatId;

  StreamSubscription<WSEvent>? _eventSubscription;

  ChatSocketService? _socket;

  bool _membershipRefreshInFlight = false;

  int? _lastHistoryCursor;
  int _historyPagesFetched = 0;
  static const int _maxHistoryPages = 20;

  @override
  Future<ChatDetailState> build() async {
    ref.onDispose(_teardown);

    final loaded = await _load();

    _attachRealtime(loaded);

    return loaded;
  }

  void _attachRealtime(ChatDetailState loaded) {
    final socket = ref.read(chatSocketServiceProvider);
    _socket = socket;

    socket.subscribe(
      _chatId,
      lastSeq: ChatRealtimeMerge.highestSeq(loaded.messages),
    );

    _eventSubscription = socket.events.listen(
      _onEvent,
      onError: (Object error, StackTrace stackTrace) {
        Logger.error(
          'ChatDetail($_chatId): event stream error',
          error,
          stackTrace,
        );
      },
      cancelOnError: false,
    );
  }

  void _teardown() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _socket?.unsubscribe(_chatId);
    _socket = null;
  }

  Future<void> _onEvent(WSEvent event) async {
    if (event is WSDomainEvent && event.chatId != _chatId) return;

    switch (event) {
      case NewMessage():
        await _onNewMessage(event);

      case MessageEdited():
        _upsertDecodedMessage(event.message);

      case MessageDeleted():
        _mutate(
          (s) => s.copyWith(
            messages: ChatRealtimeMerge.applyMessageDeleted(
              s.messages,
              event.messageId,
              asTombstone: true,
            ),
            clearReplyTo: s.replyTo?.id == event.messageId,
            nextCursor: s.nextCursor,
          ),
        );

      case WsHistory():
        if (event.chatId != _chatId) return;
        _onHistory(event);

      case MessagesRead():
        _onMessagesRead(event);

      case ReactionUpdated():
        _onReactionUpdated(event);

      case ChatUpdated():
        _mutate((s) {
          final chat = s.chat;
          if (chat == null) return s;
          return s.copyWith(
            chat: ChatRealtimeMerge.applyChatUpdated(
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
            nextCursor: s.nextCursor,
          );
        });

      case ChatDeleted():
        _mutate((s) => s.copyWith(isGone: true, nextCursor: s.nextCursor));

      case MemberKick():
        await _onMembershipChange(event.targetUserId, removed: true);

      case MemberBanned():
        await _onMembershipChange(event.targetUserId, removed: event.ban);

      case MemberLeft():
        await _onMembershipChange(event.userId, removed: true);

      case MemberJoined():
        _bumpMemberCount(1);
        _invalidateMembers();

      case AttachmentSuccess():
        break;

      case ChatCreated():
        break;

      case WsReady():
        break;

      case WsErrorNotChatMember():
        // `ws.error` is the only signal that realtime is off for this chat;
        // without surfacing it the screen just silently stops updating.
        if (event.chatId == null || event.chatId == _chatId) {
          _mutate(
            (s) =>
                s.copyWith(isRealtimeRejected: true, nextCursor: s.nextCursor),
          );
        }

      case WsSubscribed():
      case WsUnsubscribed():
      case WsPing():
      case WsPong():
      case WsErrorBadCommand():
      case WsAuthInvalid():
      case WsUnimplementedEvent():
      case WsUnknown():
        break;
    }
  }

  Future<void> _onNewMessage(NewMessage event) async {
    final message = _upsertDecodedMessage(event.message);
    if (message == null) return;

    await _markReadUpTo(message.seq);
  }

  MessageEntity? _upsertDecodedMessage(Map<String, dynamic> raw) {
    final message = _decodeMessage(raw);
    if (message == null) return null;

    _mutate(
      (s) => s.copyWith(
        messages: ChatRealtimeMerge.upsertMessage(s.messages, message),
        nextCursor: s.nextCursor,
      ),
    );
    return message;
  }

  MessageEntity? _decodeMessage(Map<String, dynamic> raw) {
    try {
      return MessageModel.fromJson(raw).toEntity();
    } catch (error) {
      Logger.warning('ChatDetail($_chatId): bad message payload: $error');
      return null;
    }
  }

  void _onHistory(WsHistory event) {
    final decoded = <MessageEntity>[];
    for (final raw in event.messages) {
      try {
        decoded.add(MessageModel.fromJson(raw).toEntity());
      } catch (error) {
        Logger.warning('ChatDetail($_chatId): bad ws.history message: $error');
      }
    }

    if (decoded.isNotEmpty) {
      _mutate((s) {
        var messages = s.messages;
        for (final message in decoded) {
          messages = ChatRealtimeMerge.upsertMessage(messages, message);
        }
        return s.copyWith(messages: messages, nextCursor: s.nextCursor);
      });

      final newest = ChatRealtimeMerge.highestSeq(decoded);
      if (newest != null) _markReadUpTo(newest);
    }

    _continueHistory(event);
  }

  void _continueHistory(WsHistory event) {
    if (!event.hasMore) {
      _historyPagesFetched = 0;
      return;
    }

    final next = event.nextLastSeq;
    if (next == null) return;

    if (_lastHistoryCursor != null && next <= _lastHistoryCursor!) return;

    if (_historyPagesFetched >= _maxHistoryPages) {
      Logger.warning(
        'ChatDetail($_chatId): stopping ws.history catch-up after '
        '$_maxHistoryPages pages; the rest loads on scroll',
      );
      return;
    }

    _historyPagesFetched++;
    _lastHistoryCursor = next;
    ref.read(chatSocketServiceProvider).subscribe(_chatId, lastSeq: next);
  }

  bool _hasMessage(String messageId) =>
      state.value?.messages.any((m) => m.id == messageId) ?? false;

  void _invalidateMembers() {
    ref.invalidate(chatMembersProvider(_chatId));
  }

  Future<void> _refreshMembershipOrLeave() async {
    if (_membershipRefreshInFlight) return;
    _membershipRefreshInFlight = true;

    try {
      final result = await ref.read(getChatUseCaseProvider).execute(_chatId);

      result.match(
        (failure) {
          if (_isAccessDenied(failure)) {
            _mutate((s) => s.copyWith(isGone: true, nextCursor: s.nextCursor));
          } else {
            Logger.warning(
              'ChatDetail($_chatId): membership refresh failed '
              '(${failure.message})',
            );
          }
        },
        (chat) =>
            _mutate((s) => s.copyWith(chat: chat, nextCursor: s.nextCursor)),
      );
    } finally {
      _membershipRefreshInFlight = false;
    }

    _invalidateMembers();
  }

  bool _isAccessDenied(Failure failure) {
    if (failure is! ApiFailure) return false;
    return const {
      'NOT_CHAT_MEMBER',
      'CHAT_ACCESS_DENIED',
      'NOT_FOUND_CHAT',
    }.contains(failure.code);
  }

  void _onMessagesRead(MessagesRead event) {
    final myId = state.value?.myUserId;
    if (event.readerId == myId) return;

    _mutate((s) {
      final known = s.peerReadSeq[event.readerId];
      if (known != null && known >= event.seq) return s;
      return s.copyWith(
        peerReadSeq: {...s.peerReadSeq, event.readerId: event.seq},
        nextCursor: s.nextCursor,
      );
    });
  }

  Future<void> _onMembershipChange(int userId, {required bool removed}) async {
    final myId = state.value?.myUserId;

    if (userId == myId) {
      if (removed) {
        _mutate((s) => s.copyWith(isGone: true, nextCursor: s.nextCursor));
      } else {
        await _refreshMembershipOrLeave();
      }
      return;
    }

    _bumpMemberCount(removed ? -1 : 1);
    _invalidateMembers();
  }

  void _bumpMemberCount(int delta) {
    _mutate((s) {
      final chat = s.chat;
      if (chat == null) return s;
      final next = chat.memberCount + delta;
      return s.copyWith(
        chat: chat.copyWith(memberCount: next < 0 ? 0 : next),
        nextCursor: s.nextCursor,
      );
    });
  }

  void _onReactionUpdated(ReactionUpdated event) {
    if (!_hasMessage(event.messageId)) return;

    final ReactionUpdateModel snapshot;
    try {
      snapshot = ReactionUpdateModel.fromJson(event.reaction);
    } catch (error) {
      Logger.warning('ChatDetail($_chatId): bad reaction payload: $error');
      return;
    }

    _mutate(
      (s) => s.copyWith(
        messages: ChatRealtimeMerge.applyReactionSnapshot(
          s.messages,
          event.messageId,
          snapshot.toGroups(),
          actorId: event.actorId,
          myUserId: s.myUserId,
        ),
        nextCursor: s.nextCursor,
      ),
    );
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final current = state.value;
    if (current == null) return;

    final before = current.reactionsFor(messageId);
    final isRemoval = before.isMine(emoji);
    final myUserId = current.myUserId;

    final policy = current.chat?.reactionPolicy;
    if (!isRemoval && policy != null && !policy.isAllowed(emoji)) return;

    _mutate(
      (s) => s.copyWith(
        messages: ChatRealtimeMerge.setReactionGroups(
          s.messages,
          messageId,
          s
              .reactionsFor(messageId)
              .toggleMine(emoji, myUserId: myUserId)
              .groups,
        ),
        nextCursor: s.nextCursor,
      ),
    );

    final result = isRemoval
        ? await ref
              .read(removeReactionUseCaseProvider)
              .execute(_chatId, messageId, emoji, current: before)
        : await ref
              .read(setReactionUseCaseProvider)
              .execute(
                _chatId,
                messageId,
                emoji,
                current: before,
                policy: policy,
              );

    result.match((failure) {
      Logger.warning(
        'ChatDetail($_chatId): reaction $emoji on $messageId failed '
        '(${failure.message})',
      );
      _rollbackReactions(messageId, before);
    }, (_) {});
  }

  Future<void> replaceReactions(String messageId, List<String> emojis) async {
    final current = state.value;
    if (current == null) return;

    final before = current.reactionsFor(messageId);
    final myUserId = current.myUserId;
    final policy = current.chat?.reactionPolicy;

    _mutate(
      (s) => s.copyWith(
        messages: ChatRealtimeMerge.setReactionGroups(
          s.messages,
          messageId,
          s
              .reactionsFor(messageId)
              .replaceMine(emojis, myUserId: myUserId)
              .groups,
        ),
        nextCursor: s.nextCursor,
      ),
    );

    final result = emojis.isEmpty
        ? await ref
              .read(clearReactionsUseCaseProvider)
              .execute(_chatId, messageId, current: before)
        : await ref
              .read(replaceReactionsUseCaseProvider)
              .execute(_chatId, messageId, emojis, policy: policy);

    result.match((failure) {
      Logger.warning(
        'ChatDetail($_chatId): replacing reactions on $messageId failed '
        '(${failure.message})',
      );
      _rollbackReactions(messageId, before);
    }, (_) {});
  }

  void _rollbackReactions(String messageId, MessageReactionsEntity before) {
    _mutate(
      (s) => s.copyWith(
        messages: ChatRealtimeMerge.setReactionGroups(
          s.messages,
          messageId,
          before.groups,
        ),
        nextCursor: s.nextCursor,
      ),
    );
  }

  void _mutate(ChatDetailState Function(ChatDetailState state) transform) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(transform(current));
  }

  Future<void> refresh() async {
    final previous = state.value;
    final next = await AsyncValue.guard(_load);
    state = next.hasError && previous != null
        ? AsyncValue.data(previous)
        : next;

    final messages = state.value?.messages;
    if (messages != null && messages.isNotEmpty) {
      ref
          .read(chatSocketServiceProvider)
          .subscribe(_chatId, lastSeq: ChatRealtimeMerge.highestSeq(messages));
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.canLoadMore || current.isLoadingMore) {
      return;
    }

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final result = await ref
        .read(getMessagesUseCaseProvider)
        .executeOlder(
          _chatId,
          MessagesPage(
            messages: const [],
            nextCursor: current.nextCursor,
            hasNext: current.hasNext,
          ),
          limit: _pageSize,
        );

    state = result.fold(
      (_) => AsyncValue.data(
        current.copyWith(isLoadingMore: false, nextCursor: current.nextCursor),
      ),
      (page) => AsyncValue.data(
        current.copyWith(
          messages: [...current.messages, ...page.messages],
          nextCursor: page.nextCursor,
          hasNext: page.hasNext,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<bool> revealMessage(String messageId, {int? seq}) async {
    final current = state.value;
    if (current == null) return false;

    if (current.messages.any((m) => m.id == messageId)) {
      _highlight(messageId);
      return true;
    }

    var targetSeq = seq;
    if (targetSeq == null) {
      final found = await ref
          .read(getMessageUseCaseProvider)
          .execute(_chatId, messageId);
      targetSeq = found.getRight().toNullable()?.seq;
    }
    if (targetSeq == null) return false;

    final result = await ref
        .read(getMessagesContextUseCaseProvider)
        .execute(_chatId, targetSeq);

    return result.match(
      (failure) {
        Logger.warning(
          'ChatDetail($_chatId): context around seq $targetSeq failed '
          '(${failure.message})',
        );
        return false;
      },
      (page) {
        if (!page.messages.any((m) => m.id == messageId)) return false;

        _mutate(
          (s) => s.copyWith(
            messages: page.messages,
            nextCursor: page.nextCursor,
            hasNext: page.hasNext,
            highlightMessageId: messageId,
            isViewingHistory: true,
          ),
        );
        return true;
      },
    );
  }

  /// Reveals the message with this per-chat `seq`.
  ///
  /// The deep-link path: `seq` is exactly what
  /// `GET /chats/{id}/messages/context/?target_seq=` wants, so unlike
  /// [revealMessage] there is nothing to look up first — one request, and the
  /// window of messages around the target replaces what was loaded.
  Future<bool> revealSeq(int seq) async {
    final current = state.value;
    if (current == null) return false;

    final loaded = _findBySeq(current.messages, seq);
    if (loaded != null) {
      _highlight(loaded.id);
      return true;
    }

    final result = await ref
        .read(getMessagesContextUseCaseProvider)
        .execute(_chatId, seq);

    return result.match(
      (failure) {
        Logger.warning(
          'ChatDetail($_chatId): context around seq $seq failed '
          '(${failure.message})',
        );
        return false;
      },
      (page) {
        final target = _findBySeq(page.messages, seq);
        if (target == null) return false;

        _mutate(
          (s) => s.copyWith(
            messages: page.messages,
            nextCursor: page.nextCursor,
            hasNext: page.hasNext,
            highlightMessageId: target.id,
            isViewingHistory: true,
          ),
        );
        return true;
      },
    );
  }

  static MessageEntity? _findBySeq(List<MessageEntity> messages, int seq) {
    for (final message in messages) {
      if (message.seq == seq) return message;
    }
    return null;
  }

  void _highlight(String messageId) {
    _mutate(
      (s) =>
          s.copyWith(highlightMessageId: messageId, nextCursor: s.nextCursor),
    );
  }

  void clearHighlight() {
    final current = state.value;
    if (current == null || current.highlightMessageId == null) return;
    _mutate((s) => s.copyWith(clearHighlight: true, nextCursor: s.nextCursor));
  }

  Future<void> returnToLatest() => refresh();

  void setReplyTo(MessageEntity? message) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      message == null
          ? current.copyWith(clearReplyTo: true, nextCursor: current.nextCursor)
          : current.copyWith(replyTo: message, nextCursor: current.nextCursor),
    );
  }

  Future<void> sendMessage({
    String? content,
    List<String> uploadTokens = const [],
    MessageType? messageType,
  }) async {
    final current = state.value;
    if (current == null) return;

    final pending = PendingMessage(
      idempotencyKey: _uuid.v4(),
      content: content,
      replyToId: current.replyTo?.id,
      uploadTokens: uploadTokens,
      messageType: messageType,
    );

    state = AsyncValue.data(
      current.copyWith(
        pending: [...current.pending, pending],
        clearReplyTo: true,
        nextCursor: current.nextCursor,
      ),
    );

    await _attemptSend(pending);
  }

  Future<void> retry(PendingMessage message) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(
        pending: [
          for (final p in current.pending)
            if (p.idempotencyKey == message.idempotencyKey)
              p.copyWith(clearFailure: true)
            else
              p,
        ],
        nextCursor: current.nextCursor,
      ),
    );

    await _attemptSend(message);
  }

  void discard(PendingMessage message) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        pending: current.pending
            .where((p) => p.idempotencyKey != message.idempotencyKey)
            .toList(),
        nextCursor: current.nextCursor,
      ),
    );
  }

  Future<void> _attemptSend(PendingMessage pending) async {
    final result = await ref
        .read(sendMessageUseCaseProvider)
        .execute(
          _chatId,
          content: pending.content,
          replyToId: pending.replyToId,
          uploadTokens: pending.uploadTokens.isEmpty
              ? null
              : pending.uploadTokens,
          messageType: pending.messageType,
          idempotencyKey: pending.idempotencyKey,
        );

    final current = state.value;
    if (current == null) return;

    state = result.fold(
      (failure) => AsyncValue.data(
        current.copyWith(
          pending: [
            for (final p in current.pending)
              if (p.idempotencyKey == pending.idempotencyKey)
                p.copyWith(failure: failure)
              else
                p,
          ],
          nextCursor: current.nextCursor,
        ),
      ),
      (message) {
        return AsyncValue.data(
          current.copyWith(
            messages: ChatRealtimeMerge.upsertMessage(
              current.messages,
              message,
            ),
            pending: current.pending
                .where((p) => p.idempotencyKey != pending.idempotencyKey)
                .toList(),
            nextCursor: current.nextCursor,
          ),
        );
      },
    );

    final sent = result.getRight().toNullable();

    if (sent != null) {
      ref.read(chatSocketServiceProvider).subscribe(_chatId, lastSeq: sent.seq);
    }

    await _markReadUpTo(sent?.seq);
  }

  Future<void> _markReadUpTo(int? seq) async {
    if (seq == null) return;
    await ref.read(markReadUseCaseProvider).execute(_chatId, seq);
  }

  Future<String?> deleteMessageReportingFailure(String messageId) async {
    try {
      await deleteMessage(messageId);
      return null;
    } on Failure catch (failure) {
      return failure.message;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final result = await ref
        .read(deleteMessageUseCaseProvider)
        .execute(_chatId, messageId);
    final current = state.value;
    if (current == null) return;
    result.match((failure) => throw failure, (_) {
      state = AsyncValue.data(
        current.copyWith(
          messages: current.messages.where((m) => m.id != messageId).toList(),
          nextCursor: current.nextCursor,
        ),
      );
    });
  }

  Future<void> editMessage(String messageId, String content) async {
    final result = await ref
        .read(editMessageUseCaseProvider)
        .execute(_chatId, messageId, content);
    final current = state.value;
    if (current == null) return;
    result.match((failure) => throw failure, (updated) {
      state = AsyncValue.data(
        current.copyWith(
          messages: [
            for (final m in current.messages)
              if (m.id == updated.id) updated else m,
          ],
          nextCursor: current.nextCursor,
        ),
      );
    });
  }

  Future<ChatDetailState> _load() async {
    final myUserId = ref.watch(authProvider).value?.id;

    final chatFuture = ref.read(getChatUseCaseProvider).execute(_chatId);
    final messagesFuture = ref
        .read(getMessagesUseCaseProvider)
        .execute(_chatId, limit: _pageSize);

    final chat = (await chatFuture).getOrElse((failure) => throw failure);
    final page = (await messagesFuture).getOrElse((failure) => throw failure);

    if (page.messages.isNotEmpty) {
      await _markReadUpTo(page.messages.first.seq);
    }

    return ChatDetailState(
      chat: chat,
      messages: page.messages,
      nextCursor: page.nextCursor,
      hasNext: page.hasNext,
      myUserId: myUserId,
    );
  }
}

final chatDetailProvider =
    AsyncNotifierProvider.family<ChatDetailController, ChatDetailState, String>(
      ChatDetailController.new,
      isAutoDispose: true,
    );
