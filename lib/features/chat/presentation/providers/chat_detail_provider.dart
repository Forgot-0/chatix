import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:chatix/features/chat/domain/entities/message_window.dart';
import 'package:chatix/features/chat/domain/entities/outbox_entry.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_members_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_realtime_merge.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_outbox_provider.dart';
import 'package:chatix/features/chat/presentation/providers/composer_provider.dart';
import 'package:chatix/features/chat/presentation/providers/reaction_notice_provider.dart';
import 'package:chatix/features/chat/presentation/providers/search_providers.dart';

const _pageSize = 30;

/// How much of a chat is drawn from the cache before the network answers.
///
/// A little more than a page, so the first frame is a full screen with
/// somewhere to scroll rather than exactly one screenful.
const _cachedWindow = 60;

/// A message the queue is still carrying, as the feed draws it.
///
/// A view of an [OutboxEntry], not a second copy of the truth: the queue owns
/// these, survives the screen and the process, and this is what one of its
/// entries looks like to a bubble. [idempotencyKey] is the entry's id, which
/// is also the `Idempotency-Key` the send carries (api-docs §5.4) — the same
/// value on every retry, so retrying cannot post the message twice.
class PendingMessage extends Equatable {
  final String idempotencyKey;

  final String? content;
  final String? replyToId;
  final List<String> uploadTokens;

  final MessageType? messageType;

  /// Why the last attempt did not work, if one has not.
  final String? failureMessage;

  /// How many attempts have been made.
  final int attempts;

  /// Set when the queue has stopped retrying on its own: from here it is
  /// Retry or Delete, and nothing happens until one of them is chosen.
  final bool needsAttention;

  const PendingMessage({
    required this.idempotencyKey,
    this.content,
    this.replyToId,
    this.uploadTokens = const [],
    this.messageType,
    this.failureMessage,
    this.attempts = 0,
    this.needsAttention = false,
  });

  /// Null for a queued entry that is not a message — a reaction or a read
  /// cursor has no bubble.
  static PendingMessage? fromOutbox(OutboxEntry entry) {
    final operation = entry.operation;
    if (operation is! OutboxSendMessage) return null;

    return PendingMessage(
      idempotencyKey: entry.id,
      content: operation.content,
      replyToId: operation.replyToId,
      uploadTokens: operation.uploadTokens,
      messageType: operation.messageType,
      failureMessage: entry.failureMessage,
      attempts: entry.attempts,
      needsAttention: entry.needsAttention,
    );
  }

  /// Whether this is still on its way rather than stuck.
  bool get isInFlight => !needsAttention;

  @override
  List<Object?> get props => [
    idempotencyKey,
    content,
    replyToId,
    uploadTokens,
    messageType,
    failureMessage,
    attempts,
    needsAttention,
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

  /// Where reading had stopped when this chat was opened, taken once from
  /// `ChatDTO.last_read.last_read_message_seq` (api-docs §5.2).
  ///
  /// Frozen on purpose. The live value moves as we report progress, and a
  /// divider that follows it walks down the screen while the reader is still
  /// looking at it.
  final int? unreadAnchorSeq;

  /// How many messages were unread when the chat was opened, frozen for the
  /// same reason as [unreadAnchorSeq].
  final int unreadAtOpen;

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
    this.unreadAnchorSeq,
    this.unreadAtOpen = 0,
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
    int? unreadAnchorSeq,
    int? unreadAtOpen,
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
      unreadAnchorSeq: unreadAnchorSeq ?? this.unreadAnchorSeq,
      unreadAtOpen: unreadAtOpen ?? this.unreadAtOpen,
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
    unreadAnchorSeq,
    unreadAtOpen,
  ];
}

class ChatDetailController extends AsyncNotifier<ChatDetailState> {
  ChatDetailController(this._chatId);

  final String _chatId;

  StreamSubscription<WSEvent>? _eventSubscription;

  StreamSubscription<ChatSocketStatus>? _statusSubscription;

  StreamSubscription<OutboxDelivery>? _deliverySubscription;

  ChatSocketService? _socket;

  bool _membershipRefreshInFlight = false;

  bool _refetchInFlight = false;

  Timer? _catchUpTimer;

  /// How much reactions looked like before a queued change to them, kept
  /// against the id of the entry that changed them, so the one that is
  /// eventually given up on can be taken back off the screen.
  final Map<String, MessageReactionsEntity> _reactionRollbacks = {};

  /// How long a connection may be gone before what is on screen stops being
  /// trustworthy.
  ///
  /// Under this, `resume` and `ws.history` close the gap exactly (api-docs
  /// §6.3). Over it the replay is likelier to be long than short, and a
  /// single `GET /messages/` is both cheaper and authoritative — it also
  /// picks up the deletions and edits that a replay cannot describe.
  static const Duration staleAfter = Duration(minutes: 10);

  int? _lastHistoryCursor;
  int _historyPagesFetched = 0;
  static const int _maxHistoryPages = 20;

  /// At most one read report every this long, however fast the reader
  /// scrolls. The furthest seq seen during the wait goes out when it ends, so
  /// nothing is lost — only the requests in between.
  static const Duration readThrottle = Duration(milliseconds: 1500);

  int? _reportedReadSeq;
  int? _queuedReadSeq;
  DateTime? _lastReadSentAt;
  Timer? _readCooldown;

  /// Set once, on the first load: everything after it keeps the divider and
  /// the opening scroll position still.
  bool _unreadFrozen = false;
  int? _unreadAnchorSeq;
  int _unreadAtOpen = 0;

  @override
  Future<ChatDetailState> build() async {
    ref.onDispose(_teardown);

    _watchOutbox();

    // Whatever this device already holds goes on screen first, without
    // waiting for anything: no await between here and the returned state, so
    // reopening a chat is a frame, not a request. The network answer follows
    // and reconciles.
    final cached = _fromCache();
    if (cached != null) {
      _attachRealtime(cached);
      _watchConnection();
      _scheduleCatchUp();
      return cached;
    }

    final loaded = await _load();

    _attachRealtime(loaded);
    _watchConnection();

    return loaded;
  }

  /// The chat as this device last saw it, or null if it has never seen it.
  ChatDetailState? _fromCache() {
    final messages = ref
        .read(getLocalMessagesUseCaseProvider)
        .execute(_chatId, limit: _cachedWindow);
    if (messages.isEmpty) return null;

    final oldest = MessageWindow.lowestSeq(messages);

    return ChatDetailState(
      // `GET /chats/{id}/` has not answered yet, so the header is drawn from
      // the list row when the list is up — and from nothing when the chat was
      // opened by link, which the screen already handles.
      chat: _listRow(),
      messages: messages,
      // The cached window is a window: there is older history behind it
      // unless it reaches the first message of the chat.
      nextCursor: oldest,
      hasNext: oldest != null && oldest > 1,
      myUserId: ref.read(authProvider).value?.id,
      pending: _pendingOf(ref.read(chatOutboxProvider)),
    );
  }

  /// Starts the catch-up once this build has settled.
  ///
  /// A timer rather than a bare call, because the cached state is still on
  /// its way through `build` at this point: anything written to `state`
  /// before that lands is overwritten by the very value being returned here.
  /// Timers run after the microtask queue drains, which is after that.
  void _scheduleCatchUp() {
    _catchUpTimer = Timer(Duration.zero, () => unawaited(_catchUp()));
  }

  /// Brings the cached window up to date over the network.
  ///
  /// A failure here is not an error state: the screen is already drawn, and
  /// the honest answer to "no network" is the chat as it was, not a blank
  /// page with a message about connectivity.
  Future<void> _catchUp() async {
    final refreshed = await AsyncValue.guard(_load);

    final loaded = refreshed.value;
    if (loaded == null) {
      Logger.warning(
        'ChatDetail($_chatId): opened from cache, catch-up failed '
        '(${refreshed.error})',
      );
      return;
    }

    _mutate(
      (s) => s.copyWith(
        chat: loaded.chat,
        messages: MessageWindow.reconcile(s.messages, loaded.messages),
        nextCursor: loaded.nextCursor,
        hasNext: loaded.hasNext,
        unreadAnchorSeq: loaded.unreadAnchorSeq,
        unreadAtOpen: loaded.unreadAtOpen,
      ),
    );

    // The socket was subscribed with the cached cursor; now that the newest
    // page is in, move it on so a replay does not repeat what just arrived.
    final highest = MessageWindow.highestSeq(state.value?.messages ?? const []);
    if (highest != null) {
      ref.read(chatSocketServiceProvider).subscribe(_chatId, lastSeq: highest);
    }
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

  /// Follows the queue: what is still on its way, and what became of it.
  ///
  /// Two channels because they answer different questions. The list is the
  /// state — which bubbles are pending right now, including ones queued
  /// before this screen existed or before this run of the app. The stream is
  /// the events — a message that landed, a reaction that was given up on.
  void _watchOutbox() {
    final outbox = ref.read(chatOutboxProvider.notifier);

    _deliverySubscription = outbox.deliveries.listen(
      _onDelivery,
      onError: (Object error, StackTrace stackTrace) {
        Logger.error('ChatDetail($_chatId): outbox stream error', error, stackTrace);
      },
      cancelOnError: false,
    );

    ref.listen<List<OutboxEntry>>(chatOutboxProvider, (_, queue) {
      _mutate((s) => s.copyWith(pending: _pendingOf(queue), nextCursor: s.nextCursor));
    });
  }

  List<PendingMessage> _pendingOf(List<OutboxEntry> queue) => [
    for (final entry in queue)
      if (entry.chatId == _chatId)
        if (PendingMessage.fromOutbox(entry) case final PendingMessage pending)
          pending,
  ];

  Future<void> _onDelivery(OutboxDelivery delivery) async {
    if (delivery.chatId != _chatId) return;

    final failure = delivery.failure;
    if (failure != null) {
      _onDeliveryFailed(delivery, failure);
      return;
    }

    _reactionRollbacks.remove(delivery.entry.id);

    final message = delivery.message;
    if (message == null) return;

    _mutate(
      (s) => s.copyWith(
        messages: ChatRealtimeMerge.upsertMessage(s.messages, message),
        nextCursor: s.nextCursor,
      ),
    );

    ref.read(chatSocketServiceProvider).subscribe(_chatId, lastSeq: message.seq);

    // Sending is the one place the client may speak for the reader without
    // asking the viewport: you have read what you are replying to.
    reportRead(message.seq);
  }

  void _onDeliveryFailed(OutboxDelivery delivery, Failure failure) {
    _reportSlowMode(failure);

    // A retryable failure is not a result. The bubble already says the
    // message is waiting, the chip is already on the message, and the queue
    // will try again — undoing either would be describing a defeat that has
    // not happened.
    if (!delivery.abandoned) return;

    final before = _reactionRollbacks.remove(delivery.entry.id);
    if (delivery.entry.operation is! OutboxReaction) return;

    final messageId = (delivery.entry.operation as OutboxReaction).messageId;

    if (before != null) {
      _rollbackReactions(messageId, before, failure);
      return;
    }

    // Queued in an earlier run, so there is no snapshot to go back to: ask
    // the server what the message actually looks like.
    unawaited(refreshMessage(messageId));
    if (failure is! CancelledFailure) {
      ref.read(reactionNoticeProvider.notifier).report(failure);
    }
  }

  /// Watches the connection for outages long enough to invalidate the window.
  void _watchConnection() {
    final socket = ref.read(chatSocketServiceProvider);

    _statusSubscription = socket.statusStream.listen((status) {
      if (status != ChatSocketStatus.ready) return;

      final outage = socket.lastOutage;
      if (outage == null || outage < staleAfter) return;

      Logger.info(
        'ChatDetail($_chatId): ${outage.inMinutes} min offline, refetching '
        'the window instead of replaying it',
      );
      unawaited(_refetchWindow());
    });
  }

  /// Throws away what is on screen and asks for the newest page again.
  ///
  /// The answer to both ways the window can stop being trustworthy: a `seq`
  /// that jumped, and an outage longer than a replay is worth. Older
  /// messages already scrolled to are kept — the page is authoritative only
  /// for the span it covers ([MessageWindow.reconcile]).
  Future<void> _refetchWindow() async {
    if (_refetchInFlight) return;
    _refetchInFlight = true;

    try {
      final result = await ref
          .read(getMessagesUseCaseProvider)
          .execute(_chatId, limit: _pageSize);

      result.match(
        (failure) => Logger.warning(
          'ChatDetail($_chatId): window refetch failed (${failure.message})',
        ),
        (page) => _mutate(
          (s) => s.copyWith(
            messages: MessageWindow.reconcile(s.messages, page.messages),
            nextCursor: s.isViewingHistory ? s.nextCursor : page.nextCursor,
            hasNext: s.isViewingHistory ? s.hasNext : page.hasNext,
          ),
        ),
      );
    } finally {
      _refetchInFlight = false;
    }
  }

  void _teardown() {
    _catchUpTimer?.cancel();
    _catchUpTimer = null;
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _deliverySubscription?.cancel();
    _deliverySubscription = null;
    _readCooldown?.cancel();
    _readCooldown = null;
    _socket?.unsubscribe(_chatId);
    _socket = null;
  }

  Future<void> _onEvent(WSEvent event) async {
    if (event is WSDomainEvent && event.chatId != _chatId) return;

    switch (event) {
      case NewMessage():
        _onNewMessage(event);

      case MessageEdited():
        _upsertDecodedMessage(event.message);

      case MessageDeleted():
        // Dropped outright rather than left as an empty shell. The bubble has
        // no tombstone state to draw, and a row saying nothing is a row that
        // still carries a timestamp, a reply target and a menu.
        _mutate(
          (s) => s.copyWith(
            messages: ChatRealtimeMerge.applyMessageDeleted(
              s.messages,
              event.messageId,
            ),
            clearReplyTo: s.replyTo?.id == event.messageId,
            nextCursor: s.nextCursor,
          ),
        );
        unawaited(
          ref
              .read(rememberMessagesUseCaseProvider)
              .forgetMessage(_chatId, event.messageId),
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

  void _onNewMessage(NewMessage event) {
    // Not marked read here on purpose: a message that arrives while the
    // reader is up in the history has not been read, and saying otherwise
    // clears a badge they never looked at. The feed reports it once it is
    // genuinely on screen.
    final known = state.value?.messages ?? const <MessageEntity>[];

    final message = _upsertDecodedMessage(event.message);
    if (message == null) return;

    // A `seq` that skipped means something never arrived — or was deleted
    // before it ever did. Either way the window on screen is no longer a
    // description of the chat, and only a fetch can say what is.
    if (MessageWindow.isGap(known, message)) {
      Logger.info(
        'ChatDetail($_chatId): seq gap before ${message.seq}, refetching',
      );
      unawaited(_refetchWindow());
    }
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

    _remember([message]);
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

      _remember(decoded);
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

    await _queueReaction(
      messageId,
      isRemoval ? OutboxReactionAction.remove : OutboxReactionAction.set,
      before,
      emoji: emoji,
    );
  }

  /// Puts a reaction change in the queue and takes one pass at sending it.
  ///
  /// The chip is already on the message by the time this is called. What the
  /// queue adds is that it stays there: a tap made with no connection is not
  /// a tap that failed, it is a tap that has not gone out yet, and it goes
  /// out when the connection comes back — or after a restart, if that is how
  /// long it takes.
  Future<void> _queueReaction(
    String messageId,
    OutboxReactionAction action,
    MessageReactionsEntity before, {
    String? emoji,
    List<String> emojis = const [],
  }) async {
    final outbox = ref.read(chatOutboxProvider.notifier);

    final entry = outbox.enqueueReaction(
      _chatId,
      messageId,
      action,
      emoji: emoji,
      emojis: emojis,
    );

    // Collapsing can cancel a change outright — a reaction added and taken
    // back before either left the device. Nothing will be delivered for it,
    // so nothing needs to be remembered to undo.
    final queued = ref
        .read(chatOutboxProvider)
        .any((candidate) => candidate.id == entry.id);
    if (queued) {
      _reactionRollbacks.putIfAbsent(entry.id, () => before);
    }

    await outbox.drain();
  }

  Future<void> replaceReactions(String messageId, List<String> emojis) async {
    final current = state.value;
    if (current == null) return;

    final before = current.reactionsFor(messageId);
    final myUserId = current.myUserId;

    // The policy check used to happen inside the use case, on the way to the
    // request. The request is now a queue entry that may not go out for a
    // while, so what the chat forbids has to be settled here — before the
    // chip is drawn, not after it has been sitting there for a minute.
    final policy = current.chat?.reactionPolicy;
    if (policy != null && emojis.any((emoji) => !policy.isAllowed(emoji))) {
      return;
    }

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

    await _queueReaction(
      messageId,
      emojis.isEmpty ? OutboxReactionAction.clear : OutboxReactionAction.replace,
      before,
      emojis: emojis,
    );
  }

  /// Puts the message back the way it was, and says so once.
  ///
  /// The chip appeared the instant it was tapped; taking it away again with
  /// no explanation reads as the app losing the tap, so the screen gets a
  /// reason to show — quietly, since nothing here is worth interrupting for.
  void _rollbackReactions(
    String messageId,
    MessageReactionsEntity before,
    Failure failure,
  ) {
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

    if (failure is CancelledFailure) return;
    ref.read(reactionNoticeProvider.notifier).report(failure);
  }

  void _mutate(ChatDetailState Function(ChatDetailState state) transform) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    final next = transform(current);
    state = AsyncValue.data(next);
    _cache(next.messages);
  }

  /// Files what is on screen where the search can find it.
  ///
  /// Every path that changes the message list ends up here or in the two
  /// callers below, so anything the reader has actually seen becomes
  /// searchable — which, with no search endpoint in the API (api-docs §5.4),
  /// is the only history there is to search.
  ///
  /// The window is handed over whole so the cache can drop messages deleted
  /// inside it; see [MessageCacheStore.remember].
  List<MessageEntity> _cached(List<MessageEntity> messages) {
    _cache(messages);
    return messages;
  }

  void _cache(List<MessageEntity> messages) {
    if (messages.isEmpty) return;
    ref
        .read(messageCacheStoreProvider)
        .remember(_chatId, messages, reconcile: true);
  }

  /// Writes messages that reached the screen without passing through a
  /// repository call — everything the socket pushed.
  ///
  /// Only those: a page fetched over REST is written down by the repository
  /// on its way here, and writing the whole window again on every reaction
  /// or read would be a disk write per tap.
  void _remember(List<MessageEntity> messages) {
    if (messages.isEmpty) return;
    unawaited(
      ref.read(rememberMessagesUseCaseProvider).execute(_chatId, messages),
    );
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
          messages: _cached([...current.messages, ...page.messages]),
          nextCursor: page.nextCursor,
          hasNext: page.hasNext,
          isLoadingMore: false,
        ),
      ),
    );
  }

  /// Re-reads one message off the API and puts it back in the feed.
  ///
  /// The way out of an attachment that came back `attachment_status: error`
  /// (api-docs §5.5). The backend never says why one failed and offers
  /// nothing to re-run, so "try again" can only mean asking what the status
  /// is now — which is the honest answer when the failure was the gateway
  /// still working rather than the file being bad, and which also picks up
  /// a `pending` slot that finished while the socket was down.
  Future<bool> refreshMessage(String messageId) async {
    final result = await ref
        .read(getMessageUseCaseProvider)
        .execute(_chatId, messageId);

    final message = result.getRight().toNullable();
    if (message == null) return false;

    _mutate(
      (s) => s.copyWith(
        messages: ChatRealtimeMerge.upsertMessage(s.messages, message),
        nextCursor: s.nextCursor,
      ),
    );
    return true;
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

  /// Pulls the loaded window back to where reading stopped.
  ///
  /// Only needed when more went unread than one page holds: the freshest page
  /// then starts above the boundary, so the divider has nowhere honest to go
  /// and the opening scroll has nothing to aim at. One
  /// `GET /messages/context/?target_seq=` around the frozen cursor puts both
  /// back in the window.
  ///
  /// Returns false when the window already covers the boundary, or when there
  /// is no boundary to find.
  Future<bool> loadUnreadWindow() async {
    final current = state.value;
    if (current == null) return false;

    final anchor = current.unreadAnchorSeq;
    if (anchor == null || anchor < 1 || current.unreadAtOpen <= 0) return false;
    if (current.messages.isEmpty) return false;

    // `messages` runs newest first, so the last entry is the oldest loaded.
    if (current.messages.last.seq <= anchor) return false;

    final result = await ref
        .read(getMessagesContextUseCaseProvider)
        .execute(_chatId, anchor);

    return result.match(
      (failure) {
        Logger.warning(
          'ChatDetail($_chatId): unread window around seq $anchor failed '
          '(${failure.message})',
        );
        return false;
      },
      (page) {
        if (page.messages.isEmpty) return false;

        _mutate(
          (s) => s.copyWith(
            messages: _cached(page.messages),
            nextCursor: page.nextCursor,
            hasNext: page.hasNext,
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

    final replyToId = current.replyTo?.id;

    // The reply banner goes first, before the queue announces the new
    // pending bubble — the announcement rebuilds the state, and clearing the
    // banner afterwards would be writing an older copy of it back.
    state = AsyncValue.data(
      current.copyWith(clearReplyTo: true, nextCursor: current.nextCursor),
    );

    final outbox = ref.read(chatOutboxProvider.notifier);
    outbox.enqueueMessage(
      _chatId,
      content: content,
      replyToId: replyToId,
      messageType: messageType,
      uploadTokens: uploadTokens,
    );

    await outbox.drain();
  }

  /// Tries a stuck message again, at a person's asking.
  Future<void> retry(PendingMessage message) =>
      ref.read(chatOutboxProvider.notifier).retry(message.idempotencyKey);

  /// Throws a stuck message away unsent.
  void discard(PendingMessage message) {
    unawaited(
      ref.read(chatOutboxProvider.notifier).discard(message.idempotencyKey),
    );
  }

  /// Hands a slow-mode refusal to the composer, which owns the clock.
  ///
  /// `429 SLOW_MODE_LIMIT` carries `detail.retry_after` in seconds (api-docs
  /// §2.6), and it outranks whatever the local countdown believed — the
  /// client's clock is a convenience, the server's is the rule. The message
  /// stays pending with its idempotency key, so the retry is the same
  /// message rather than a second one.
  void _reportSlowMode(Failure failure) {
    if (failure is! ApiFailure) return;
    if (failure.code != 'SLOW_MODE_LIMIT') return;

    final detail = failure.detail;
    final retryAfter = detail is Map ? detail['retry_after'] : null;

    final seconds = switch (retryAfter) {
      final int value => value,
      final num value => value.ceil(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    };

    ref.read(composerProvider(_chatId).notifier).applyRetryAfter(seconds);
  }

  /// Records how far the reader has actually got.
  ///
  /// Called with the highest seq the viewport has really shown, as often as
  /// scrolling produces one. At most one `POST /messages/read/` leaves per
  /// [readThrottle]; anything that arrives during the wait is collapsed into
  /// a single trailing request with the furthest seq.
  void reportRead(int seq) {
    if (seq < 1) return;
    if (_reportedReadSeq != null && seq <= _reportedReadSeq!) return;

    final sentAt = _lastReadSentAt;
    final since = sentAt == null ? null : DateTime.now().difference(sentAt);

    if (since == null || since >= readThrottle) {
      _sendRead(seq);
      return;
    }

    // Inside the window: keep the furthest point and let one trailing request
    // carry it out once the window closes. The timer exists only while there
    // is something waiting for it.
    final queued = _queuedReadSeq;
    if (queued == null || seq > queued) _queuedReadSeq = seq;
    _readCooldown ??= Timer(readThrottle - since, _flushRead);
  }

  void _sendRead(int seq) {
    _reportedReadSeq = seq;
    _queuedReadSeq = null;
    _lastReadSentAt = DateTime.now();

    // Queued rather than sent, for the case the throttle cannot help with:
    // reading a chat with no connection. The cursor is kept, collapsed with
    // whatever else is queued for this chat, and reported once — with the
    // furthest seq — when there is a connection to report it on.
    final outbox = ref.read(chatOutboxProvider.notifier);
    outbox.enqueueRead(_chatId, seq);
    unawaited(outbox.drain());
  }

  void _flushRead() {
    _readCooldown = null;

    final queued = _queuedReadSeq;
    _queuedReadSeq = null;
    if (queued == null) return;
    if (_reportedReadSeq != null && queued <= _reportedReadSeq!) return;

    _sendRead(queued);
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

  /// The row the chat list already holds for this chat, if it holds one.
  ///
  /// Read rather than watched, and only when the list is already alive:
  /// starting it from here would turn opening a chat by link into a fetch of
  /// the whole list.
  ChatEntity? _listRow() {
    if (!ref.exists(chatListProvider)) return null;

    for (final chat in ref.read(chatListProvider).value?.items ??
        const <ChatEntity>[]) {
      if (chat.id == _chatId) return chat;
    }
    return null;
  }

  Future<ChatDetailState> _load() async {
    final myUserId = ref.watch(authProvider).value?.id;

    final chatFuture = ref.read(getChatUseCaseProvider).execute(_chatId);
    final messagesFuture = ref
        .read(getMessagesUseCaseProvider)
        .execute(_chatId, limit: _pageSize);

    final chat = (await chatFuture).getOrElse((failure) => throw failure);
    final page = (await messagesFuture).getOrElse((failure) => throw failure);

    // Read state is taken from the chat exactly once. A refresh later in the
    // session re-fetches a cursor we ourselves have moved, and adopting it
    // would drag the divider down the screen mid-read.
    // What this device already told the server, so a restart does not
    // re-report the same cursor on the first scroll.
    _reportedReadSeq ??= ref
        .read(rememberMessagesUseCaseProvider)
        .reportedReadSeq(_chatId);

    if (!_unreadFrozen) {
      _unreadFrozen = true;

      // `GET /chats/{id}/` answers with `ChatDetailDTO`, which carries
      // neither `last_read` nor `unread_count` (api-docs §5.2) — both are
      // fields of the list row. So the row is where the divider comes from
      // when the list is up, which it is whenever a chat was opened from it.
      final row = _listRow();

      _unreadAnchorSeq =
          chat.lastRead?.lastReadMessageSeq ??
          row?.lastRead?.lastReadMessageSeq;
      _unreadAtOpen = chat.unreadCount ?? row?.unreadCount ?? 0;
    }

    _cache(page.messages);

    return ChatDetailState(
      chat: chat,
      messages: page.messages,
      nextCursor: page.nextCursor,
      hasNext: page.hasNext,
      myUserId: myUserId,
      // A message queued before this screen existed — in this run or an
      // earlier one — belongs at the bottom of the feed from the first frame,
      // not from whenever the queue next moves.
      pending: _pendingOf(ref.read(chatOutboxProvider)),
      unreadAnchorSeq: _unreadAnchorSeq,
      unreadAtOpen: _unreadAtOpen,
    );
  }
}

final chatDetailProvider =
    AsyncNotifierProvider.family<ChatDetailController, ChatDetailState, String>(
      ChatDetailController.new,
      isAutoDispose: true,
    );
