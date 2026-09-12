import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
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
    this.source = MessageSearchSource.localCache,
    this.isCapped = false,
  });

  final String query;

  /// Newest first, which is the order a chat is read in.
  final List<MessageSearchHit> hits;

  /// Which hit the chat is parked on.
  final int index;

  final bool isSearching;

  final MessageSearchSource source;

  /// There were more matches than the search returned.
  final bool isCapped;

  bool get hasQuery => query.isNotEmpty;

  bool get hasHits => hits.isNotEmpty;

  MessageSearchHit? get current =>
      index >= 0 && index < hits.length ? hits[index] : null;

  /// Human counting: "3 of 12".
  int get position => hits.isEmpty ? 0 : index + 1;

  /// Older messages are further down the list of hits.
  bool get canGoOlder => index < hits.length - 1;

  bool get canGoNewer => index > 0;

  InChatSearchState copyWith({
    String? query,
    List<MessageSearchHit>? hits,
    int? index,
    bool? isSearching,
    MessageSearchSource? source,
    bool? isCapped,
  }) {
    return InChatSearchState(
      query: query ?? this.query,
      hits: hits ?? this.hits,
      index: index ?? this.index,
      isSearching: isSearching ?? this.isSearching,
      source: source ?? this.source,
      isCapped: isCapped ?? this.isCapped,
    );
  }

  @override
  List<Object?> get props => [
    query,
    hits,
    index,
    isSearching,
    source,
    isCapped,
  ];
}

/// The search inside one chat.
///
/// Hits come from the same place the global message search gets them — what
/// this device has loaded — but jumping to one does not: the chat asks the
/// server for the window around that message
/// (`GET /chats/{id}/messages/context/?target_seq=`, api-docs §5.4), so a
/// match found in a preview still opens at the right place in the history.
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

    state = state.copyWith(query: next, isSearching: true);

    _timer = Timer(SearchQueryController.debounce, () {
      if (!ref.mounted) return;
      unawaited(_run(next));
    });
  }

  void submit(String raw) {
    _timer?.cancel();
    final next = raw.trim();
    if (next.isEmpty) {
      clear();
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
        );
      },
      (found) {
        final hits = [...found.hits]
          ..sort((a, b) => b.seq.compareTo(a.seq));

        state = state.copyWith(
          hits: hits,
          index: 0,
          isSearching: false,
          source: found.source,
          isCapped: found.isCapped,
        );

        // Land on the newest match, the way the field's own result would.
        if (hits.isNotEmpty) unawaited(_reveal(hits.first));
      },
    );
  }

  Future<void> _moveTo(int index) async {
    final hits = state.hits;
    if (index < 0 || index >= hits.length) return;

    state = state.copyWith(index: index);
    await _reveal(hits[index]);
  }

  Future<void> _reveal(MessageSearchHit hit) async {
    final revealed = await ref
        .read(chatDetailProvider(_chatId).notifier)
        .revealSeq(hit.seq);

    if (revealed) return;

    Logger.warning(
      'InChatSearch($_chatId): could not open message ${hit.seq}',
    );
  }
}

final inChatSearchProvider =
    NotifierProvider.family<InChatSearchController, InChatSearchState, String>(
      InChatSearchController.new,
      isAutoDispose: true,
    );
