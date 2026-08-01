import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

const _pageSize = 30;
const _uuid = Uuid();

/// One message the user asked to send that hasn't been acknowledged yet.
///
/// Exists to hold the **idempotency key** alongside the draft. The key is
/// minted once, when the user first presses send, and reused by every retry of
/// that same logical message — that is the whole point of `Idempotency-Key`
/// (api-docs §6.4): within 24 h the backend answers a repeated key with the
/// cached first result instead of creating a duplicate.
///
/// Without this record a retry would mint a fresh key and the "no network →
/// tap send again on reconnect" flow would post the message twice, which is
/// exactly the scenario the header exists to prevent.
class PendingMessage extends Equatable {
  /// Stable across retries — never regenerated.
  final String idempotencyKey;

  final String? content;
  final String? replyToId;
  final List<String> uploadTokens;

  /// Set after an attempt fails, so the row can show why and offer Retry.
  final Failure? failure;

  const PendingMessage({
    required this.idempotencyKey,
    this.content,
    this.replyToId,
    this.uploadTokens = const [],
    this.failure,
  });

  PendingMessage copyWith({Failure? failure, bool clearFailure = false}) {
    return PendingMessage(
      idempotencyKey: idempotencyKey,
      content: content,
      replyToId: replyToId,
      uploadTokens: uploadTokens,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
    idempotencyKey,
    content,
    replyToId,
    uploadTokens,
    failure,
  ];
}

/// State of a single chat screen: the chat itself, the loaded slice of its
/// history and anything still in flight.
///
/// ⚠️ REST-only for now. Nothing here reacts to another participant's
/// activity — new messages appear on pull-to-refresh or when this user sends
/// one. The live stream (api-docs §7) is a separate layer that will push into
/// this same controller.
class ChatDetailState extends Equatable {
  final ChatEntity? chat;

  /// Newest first, matching the order the API returns (api-docs §6.4). The
  /// screen renders a `reverse: true` list, so no re-sorting happens.
  final List<MessageEntity> messages;

  /// Cursor for the next page of *older* messages.
  final int? nextCursor;
  final bool hasNext;
  final bool isLoadingMore;

  /// Sends awaiting a server reply, oldest first.
  final List<PendingMessage> pending;

  /// The message the composer is replying to, if any.
  final MessageEntity? replyTo;

  /// The signed-in user's id, captured when the chat was loaded.
  ///
  /// Required to resolve [me]: this screen's chat comes from
  /// `GET /chats/{id}/`, i.e. a `ChatDetaiDTO`, which carries the full
  /// `members` list and **no `me` field** (api-docs §6.2). Without an id
  /// there is nothing to match a row against, so every permission check
  /// would fail closed and the composer would be permanently disabled.
  final int? myUserId;

  const ChatDetailState({
    this.chat,
    this.messages = const [],
    this.nextCursor,
    this.hasNext = false,
    this.isLoadingMore = false,
    this.pending = const [],
    this.replyTo,
    this.myUserId,
  });

  bool get canLoadMore => hasNext && nextCursor != null;

  /// The caller's own membership, from whichever field this chat carries it in
  /// — the input to every permission check on the screen.
  ///
  /// ⚠️ Resolved through [ChatEntity.membershipOf] rather than reading
  /// `chat.me` directly: `me` is only populated on a `ChatDTO` (the list,
  /// create and update responses), while `GET /chats/{id}/` returns a
  /// `ChatDetaiDTO` whose membership lives in `members` (api-docs §6.2).
  /// Reading `chat.me` here always yielded `null`, which silently denied
  /// every permission — including `message:send` to a chat's own owner.
  ///
  /// `null` is a legitimate answer for a non-member previewing a public chat,
  /// and must be treated as "deny" (fail-closed) by callers.
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
  }) {
    return ChatDetailState(
      chat: chat ?? this.chat,
      messages: messages ?? this.messages,
      myUserId: myUserId ?? this.myUserId,
      // Replaced wholesale, including back to null when history is exhausted:
      // a stale cursor would re-read the same window forever.
      nextCursor: nextCursor,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pending: pending ?? this.pending,
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
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
  ];
}

/// Drives `ChatDetailScreen` for one `chatId`.
class ChatDetailController
    extends AsyncNotifier<ChatDetailState> {
  ChatDetailController(this._chatId);

  /// The chat this controller is scoped to. Riverpod 3's manual `family` API
  /// hands the argument to the constructor (there is no inherited `arg`), so
  /// the provider below forwards it.
  final String _chatId;

  @override
  Future<ChatDetailState> build() => _load();

  Future<void> refresh() async {
    // Keeps the current frame on screen while re-fetching (no spinner flash)
    // — the list is long-lived and the user is usually reading it.
    final previous = state.value;
    final next = await AsyncValue.guard(_load);
    state = next.hasError && previous != null
        ? AsyncValue.data(previous)
        : next;
  }

  /// Appends the next page of older history.
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
      // Drop the spinner but keep the history already read — losing a
      // scrolled-through conversation because one page failed is far worse
      // than the missing page.
      (_) => AsyncValue.data(
        current.copyWith(
          isLoadingMore: false,
          nextCursor: current.nextCursor,
        ),
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

  void setReplyTo(MessageEntity? message) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      message == null
          ? current.copyWith(clearReplyTo: true, nextCursor: current.nextCursor)
          : current.copyWith(replyTo: message, nextCursor: current.nextCursor),
    );
  }

  /// Sends [content] (and/or [uploadTokens]) as a new message.
  ///
  /// Mints one idempotency key here and hands it to [_attemptSend]; [retry]
  /// reuses the very same key, which is what makes a retry safe.
  Future<void> sendMessage({
    String? content,
    List<String> uploadTokens = const [],
  }) async {
    final current = state.value;
    if (current == null) return;

    final pending = PendingMessage(
      idempotencyKey: _uuid.v4(),
      content: content,
      replyToId: current.replyTo?.id,
      uploadTokens: uploadTokens,
    );

    state = AsyncValue.data(
      current.copyWith(
        pending: [...current.pending, pending],
        // The composer's reply banner clears immediately — the reply target is
        // already captured in `pending`.
        clearReplyTo: true,
        nextCursor: current.nextCursor,
      ),
    );

    await _attemptSend(pending);
  }

  /// Re-sends a failed message **with its original key**, so if the first
  /// attempt actually reached the server the backend returns that same
  /// message instead of creating a second one (api-docs §6.4).
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

  /// Abandons a failed send.
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
        // The server's message replaces the pending row. Guard against the
        // idempotent-replay case: replaying a key returns a message we may
        // already be displaying, and appending it blindly would show it twice.
        final alreadyPresent = current.messages.any((m) => m.id == message.id);
        return AsyncValue.data(
          current.copyWith(
            messages: alreadyPresent
                ? current.messages
                : [message, ...current.messages],
            pending: current.pending
                .where((p) => p.idempotencyKey != pending.idempotencyKey)
                .toList(),
            nextCursor: current.nextCursor,
          ),
        );
      },
    );

    await _markReadUpTo(result.getRight().toNullable()?.seq);
  }

  /// Marks the chat read up to [seq] (api-docs §6.4). Fire-and-forget: a
  /// failed read receipt must never surface as a send error.
  Future<void> _markReadUpTo(int? seq) async {
    if (seq == null) return;
    await ref.read(markReadUseCaseProvider).execute(_chatId, seq);
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
          messages: current.messages
              .where((m) => m.id != messageId)
              .toList(),
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
    // Who "me" is, for the §9.1 permission checks below. Watched (not read)
    // so signing in/out rebuilds the chat with the right membership instead
    // of leaving a stale one on screen.
    final myUserId = ref.watch(authProvider).value?.id;

    // `GET /chats/{id}/` and the first page of history are independent
    // requests — issued together so opening a chat costs one round-trip of
    // latency instead of two.
    //
    // Typed explicitly rather than through `Future.wait`: a `Future.wait` of
    // two differently-typed `Either`s degrades to `List<Object?>` and forces
    // `as dynamic` casts that move type errors to runtime.
    final chatFuture = ref.read(getChatUseCaseProvider).execute(_chatId);
    final messagesFuture = ref
        .read(getMessagesUseCaseProvider)
        .execute(_chatId, limit: _pageSize);

    final chat = (await chatFuture).getOrElse((failure) => throw failure);
    final page = (await messagesFuture).getOrElse((failure) => throw failure);

    // Opening a chat with unread messages is itself a read event; the newest
    // loaded `seq` is the high-water mark (api-docs §6.4).
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
    AsyncNotifierProvider.family<
      ChatDetailController,
      ChatDetailState,
      String
    >(ChatDetailController.new);