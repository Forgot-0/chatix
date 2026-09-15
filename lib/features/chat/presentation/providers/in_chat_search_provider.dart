import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/domain/usecases/search_messages_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_search_provider.dart';
import 'package:chatix/features/chat/presentation/providers/search_providers.dart';

/// Finding something inside one conversation.
class InChatSearchState extends Equatable {
  const InChatSearchState({
    this.query = '',
    this.hits = const <MessageSearchHit>[],
    this.index = 0,
    this.isSearching = false,
    this.source = MessageSearchSource.server,
    this.hasNext = false,
    this.nextMessageId,
  });

  final String query;

  /// Newest first, which is the order a chat is read in.
  final List<MessageSearchHit> hits;

  /// Which hit the chat is parked on.
  final int index;

  final bool isSearching;

  final MessageSearchSource source;

  /// More matches further back than this page reached.
  final bool hasNext;

  final String? nextMessageId;

  bool get isLocal => source == MessageSearchSource.localCache;

  bool get hasQuery => query.isNotEmpty;

  bool get hasHits => hits.isNotEmpty;

  MessageSearchHit? get current =>
      index >= 0 && index < hits.length ? hits[index] : null;

  /// Human counting: "3 of 12".
  int get position => hits.isEmpty ? 0 : index + 1;

  /// Older messages are further down the list of hits, and past the end of
  /// them if the search has another page to fetch.
  bool get canGoOlder =>
      index < hits.length - 1 || (hasNext && nextMessageId != null);

  bool get canGoNewer => index > 0;

  InChatSearchState copyWith({
    String? query,
    List<MessageSearchHit>? hits,
    int? index,
    bool? isSearching,
    MessageSearchSource? source,
    bool? hasNext,
    String? nextMessageId,
  }) {
    return InChatSearchState(
      query: query ?? this.query,
      hits: hits ?? this.hits,
      index: index ?? this.index,
      isSearching: isSearching ?? this.isSearching,
      source: source ?? this.source,
      hasNext: hasNext ?? this.hasNext,
      nextMessageId: nextMessageId ?? this.nextMessageId,
    );
  }

  @override
  List<Object?> get props => [
    query,
    hits,
    index,
    isSearching,
    source,
    hasNext,
    nextMessageId,
  ];
}

/// The search inside one chat.
///
/// The same endpoint as the global search, narrowed with `chat_id`
/// (api-docs §5.4.1), so it reaches history this device has never loaded.
/// Jumping to a match is a second request — the window around it,
/// `GET /chats/{id}/messages/context/?target_seq=` — which is what makes
/// opening one of those hits possible at all.
class InChatSearchController extends Notifier<InChatSearchState> {
  InChatSearchController(this._chatId);

  final String _chatId;

  Timer? _timer;

  /// Guards against an older search landing after a newer one.
  int _runId = 0;

  @override
  InChatSearchState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return const InChatSearchState();
  }

  void type(String raw) {
    _timer?.cancel();

    final next = raw.trim();
    if (next == state.query) return;

    if (next.isEmpty) {
      _runId++;
      state = const InChatSearchState();
      return;
    }

    if (next.length < SearchMessagesUseCase.minQueryLength) {
      _runId++;
      state = InChatSearchState(query: next);
      return;
    }

    state = state.copyWith(query: next, isSearching: true);

    _timer = Timer(SearchQueryController.debounce, () {
      if (!ref.mounted) return;
      unawaited(_run(next));
    });
  }

  void submit(String raw) {
    _timer?.cancel();
    final next = raw.trim();

    if (next.length < SearchMessagesUseCase.minQueryLength) {
      _runId++;
      state = InChatSearchState(query: next);
      return;
    }

    state = state.copyWith(query: next, isSearching: true);
    unawaited(_run(next));
  }

  void clear() {
    _timer?.cancel();
    _runId++;
    state = const InChatSearchState();
  }

  /// Moves to the next match further back in time and takes the chat there.
  Future<void> goOlder() => _moveTo(state.index + 1);

  Future<void> goNewer() => _moveTo(state.index - 1);

  Future<void> jumpTo(int index) => _moveTo(index);

  Future<void> _run(String needle) async {
    final runId = ++_runId;

    final result = await ref
        .read(searchMessagesUseCaseProvider)
        .execute(needle, chatId: _chatId);

    if (!ref.mounted || runId != _runId) return;

    result.match(
      (failure) {
        Logger.warning(
          'InChatSearch($_chatId): search failed (${failure.message})',
        );
        state = state.copyWith(
          hits: const [],
          index: 0,
          isSearching: false,
          hasNext: false,
        );
      },
      (found) {
        state = state.copyWith(
          hits: found.hits,
          index: 0,
          isSearching: false,
          source: found.source,
          hasNext: found.hasNext,
          nextMessageId: found.nextMessageId,
        );

        // Land on the newest match, the way the field's own result would.
        if (found.hits.isNotEmpty) unawaited(_reveal(found.hits.first));
      },
    );
  }

  /// Fetches the page behind the one in hand.
  ///
  /// Walking back through matches is how anyone reaches the end of a page,
  /// so the next one is fetched the moment the arrow runs out of hits rather
  /// than on a scroll nobody makes here.
  Future<bool> _loadMore() async {
    final cursor = state.nextMessageId;
    if (!state.hasNext || cursor == null || state.isSearching) return false;

    final runId = _runId;
    state = state.copyWith(isSearching: true);

    final result = await ref
        .read(searchMessagesUseCaseProvider)
        .execute(state.query, chatId: _chatId, lastMessageId: cursor);

    if (!ref.mounted || runId != _runId) return false;

    return result.match(
      (failure) {
        Logger.warning(
          'InChatSearch($_chatId): next page failed (${failure.message})',
        );
        state = state.copyWith(isSearching: false, hasNext: false);
        return false;
      },
      (found) {
        state = state.copyWith(
          hits: [...state.hits, ...found.hits],
          isSearching: false,
          hasNext: found.hasNext,
          nextMessageId: found.nextMessageId,
        );
        return found.hits.isNotEmpty;
      },
    );
  }

  Future<void> _moveTo(int index) async {
    if (index < 0) return;

    if (index >= state.hits.length) {
      final grew = await _loadMore();
      if (!grew || index >= state.hits.length) return;
    }

    state = state.copyWith(index: index);
    await _reveal(state.hits[index]);
  }

  Future<void> _reveal(MessageSearchHit hit) async {
    final revealed = await ref
        .read(chatDetailProvider(_chatId).notifier)
        .revealSeq(hit.seq);

    if (revealed) return;

    Logger.warning('InChatSearch($_chatId): could not open message ${hit.seq}');
  }
}

final inChatSearchProvider =
    NotifierProvider.family<InChatSearchController, InChatSearchState, String>(
      InChatSearchController.new,
      isAutoDispose: true,
    );
