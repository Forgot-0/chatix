import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/presentation/providers/search_providers.dart';

/// What an empty search box has to show for itself.
class SearchHistory extends Equatable {
  const SearchHistory({
    this.queries = const <String>[],
    this.chatIds = const <String>[],
  });

  /// Most recent first.
  final List<String> queries;

  /// Chat ids, most recently opened first.
  final List<String> chatIds;

  bool get isEmpty => queries.isEmpty && chatIds.isEmpty;

  @override
  List<Object?> get props => [queries, chatIds];
}

class SearchHistoryController extends Notifier<SearchHistory> {
  /// Enough to be useful, few enough to read without scrolling.
  static const int maxQueries = 8;
  static const int maxChats = 12;

  /// A query is only worth remembering once it is something someone meant to
  /// type; single letters are what a search box sees on the way to a word.
  static const int minQueryLength = 2;

  @override
  SearchHistory build() {
    final store = ref.watch(searchHistoryStoreProvider);
    return SearchHistory(
      queries: store.readQueries().take(maxQueries).toList(),
      chatIds: store.readChatIds().take(maxChats).toList(),
    );
  }

  /// Records a search someone actually acted on.
  ///
  /// Called when a result is opened rather than on every keystroke, so the
  /// list holds searches that went somewhere instead of every prefix typed
  /// on the way there.
  void rememberQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.length < minQueryLength) return;

    final next = [
      trimmed,
      ...state.queries.where(
        (q) => q.toLowerCase() != trimmed.toLowerCase(),
      ),
    ].take(maxQueries).toList();

    if (next.length == state.queries.length &&
        next.first == state.queries.firstOrNull) {
      return;
    }

    state = SearchHistory(queries: next, chatIds: state.chatIds);
    _persistQueries(next);
  }

  void removeQuery(String query) {
    final next = state.queries.where((q) => q != query).toList();
    if (next.length == state.queries.length) return;

    state = SearchHistory(queries: next, chatIds: state.chatIds);
    _persistQueries(next);
  }

  void clearQueries() {
    if (state.queries.isEmpty) return;

    state = SearchHistory(queries: const [], chatIds: state.chatIds);
    _persistQueries(const []);
  }

  /// Records a chat someone opened, wherever they opened it from.
  void rememberChat(String chatId) {
    if (chatId.isEmpty) return;
    if (state.chatIds.firstOrNull == chatId) return;

    final next = [
      chatId,
      ...state.chatIds.where((id) => id != chatId),
    ].take(maxChats).toList();

    state = SearchHistory(queries: state.queries, chatIds: next);

    unawaited(
      ref
          .read(searchHistoryStoreProvider)
          .writeChatIds(next)
          .catchError(
            (Object error) =>
                Logger.warning('Search history: chats not persisted ($error)'),
          ),
    );
  }

  /// Drops a chat that is gone, so the recents cannot offer a dead row.
  void forgetChat(String chatId) {
    final next = state.chatIds.where((id) => id != chatId).toList();
    if (next.length == state.chatIds.length) return;

    state = SearchHistory(queries: state.queries, chatIds: next);
    unawaited(
      ref
          .read(searchHistoryStoreProvider)
          .writeChatIds(next)
          .catchError(
            (Object error) =>
                Logger.warning('Search history: chats not persisted ($error)'),
          ),
    );
  }

  void _persistQueries(List<String> queries) {
    unawaited(
      ref
          .read(searchHistoryStoreProvider)
          .writeQueries(queries)
          .catchError(
            (Object error) => Logger.warning(
              'Search history: queries not persisted ($error)',
            ),
          ),
    );
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryController, SearchHistory>(
      SearchHistoryController.new,
    );
