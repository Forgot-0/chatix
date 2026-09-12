import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_search.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/search_providers.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

/// The three things a search can be looking for.
enum SearchTab { chats, people, messages }

/// The query the results are for, which is not the same as what is in the
/// field: it lags by [SearchQueryController.debounce] so that typing a word
/// is one search rather than five.
class SearchQueryController extends Notifier<String> {
  static const Duration debounce = Duration(milliseconds: 250);

  Timer? _timer;

  @override
  String build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return '';
  }

  /// Called on every keystroke.
  void type(String raw) {
    _timer?.cancel();

    final next = raw.trim();
    if (next == state) return;

    // Clearing is not a search, so it does not wait: the history should come
    // back the moment the field is empty.
    if (next.isEmpty) {
      state = '';
      return;
    }

    _timer = Timer(debounce, () {
      if (!ref.mounted) return;
      state = next;
    });
  }

  /// Skips the wait — what the keyboard's search key means.
  void submit(String raw) {
    _timer?.cancel();
    final next = raw.trim();
    if (next != state) state = next;
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryController, String>(
  SearchQueryController.new,
);

class SearchTabController extends Notifier<SearchTab> {
  @override
  SearchTab build() => SearchTab.chats;

  void select(SearchTab tab) {
    if (state == tab) return;
    state = tab;
  }
}

final searchTabProvider = NotifierProvider<SearchTabController, SearchTab>(
  SearchTabController.new,
);

/// Chats matching the query, out of the ones already loaded.
///
/// No request and no loading state: `GET /chats/` has no search parameter
/// (api-docs §5.2), so this is a filter over the pages the list has pulled.
final chatSearchResultsProvider = Provider<List<ChatSearchHit>>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return const <ChatSearchHit>[];

  final chats = ref.watch(chatListProvider).value?.items ?? const <ChatEntity>[];

  return searchLoadedChats(
    chats,
    query,
    myUserId: ref.watch(authProvider.select((user) => user.value?.id)),
  );
});

/// Messages matching the query, out of what this device has loaded.
///
/// Seeds the cache from the chat list first: every row carries its own
/// `last_message` (api-docs §5.2), so the newest message of every chat is
/// searchable from a cold start, before any conversation has been opened.
final messageSearchProvider =
    FutureProvider.family<MessageSearchResult, String>((ref, query) async {
      if (query.trim().isEmpty) return MessageSearchResult.empty;

      final store = ref.watch(messageCacheStoreProvider);
      final chats =
          ref.watch(chatListProvider).value?.items ?? const <ChatEntity>[];

      for (final chat in chats) {
        final last = chat.lastMessage;
        if (last != null) store.remember(chat.id, [last]);
      }

      final result = await ref
          .watch(searchMessagesUseCaseProvider)
          .execute(query);

      return result.getOrElse((failure) => throw failure);
    }, isAutoDispose: true, retry: _neverRetry);

/// A page of people, merged out of the two fields the endpoint can filter on.
class PeopleSearchState extends Equatable {
  const PeopleSearchState({
    this.people = const <ProfileEntity>[],
    this.page = 1,
    this.usernameHasNext = false,
    this.displayNameHasNext = false,
    this.isLoadingMore = false,
  });

  final List<ProfileEntity> people;

  /// The page number both halves of the search are on.
  final int page;

  final bool usernameHasNext;
  final bool displayNameHasNext;
  final bool isLoadingMore;

  bool get hasNext => usernameHasNext || displayNameHasNext;

  bool get isEmpty => people.isEmpty;

  PeopleSearchState copyWith({
    List<ProfileEntity>? people,
    int? page,
    bool? usernameHasNext,
    bool? displayNameHasNext,
    bool? isLoadingMore,
  }) {
    return PeopleSearchState(
      people: people ?? this.people,
      page: page ?? this.page,
      usernameHasNext: usernameHasNext ?? this.usernameHasNext,
      displayNameHasNext: displayNameHasNext ?? this.displayNameHasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    people,
    page,
    usernameHasNext,
    displayNameHasNext,
    isLoadingMore,
  ];
}

/// People matching the query, from `GET /profiles/`.
///
/// The endpoint filters on `username` and `display_name` separately and the
/// docs do not say whether passing both narrows or widens (api-docs §4.2), so
/// this asks for each and merges. Both requests share one cancellation, and
/// the provider is keyed by the query: the moment a new query arrives this
/// instance is disposed, which cancels whatever was still in flight.
class PeopleSearchController extends AsyncNotifier<PeopleSearchState> {
  PeopleSearchController(this._query);

  static const int pageSize = 20;

  final String _query;

  @override
  Future<PeopleSearchState> build() async {
    final needle = _query.trim();
    if (needle.isEmpty) return const PeopleSearchState();

    final cancellation = RequestCancellation();
    ref.onDispose(cancellation.cancel);

    return _fetch(needle, page: 1, cancellation: cancellation);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.isLoadingMore) return;

    final needle = _query.trim();
    if (needle.isEmpty) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final cancellation = RequestCancellation();
    ref.onDispose(cancellation.cancel);

    final next = await _fetch(
      needle,
      page: current.page + 1,
      cancellation: cancellation,
      onlyUsername: current.usernameHasNext,
      onlyDisplayName: current.displayNameHasNext,
    );

    if (!ref.mounted) return;

    final latest = state.value ?? current;
    state = AsyncValue.data(
      latest.copyWith(
        people: _merge(latest.people, next.people),
        page: next.page,
        usernameHasNext: next.usernameHasNext,
        displayNameHasNext: next.displayNameHasNext,
        isLoadingMore: false,
      ),
    );
  }

  Future<PeopleSearchState> _fetch(
    String needle, {
    required int page,
    required RequestCancellation cancellation,
    bool onlyUsername = true,
    bool onlyDisplayName = true,
  }) async {
    final useCase = ref.read(getProfilesUseCaseProvider);

    final responses = await Future.wait([
      if (onlyUsername)
        useCase.execute(
          username: needle,
          page: page,
          pageSize: pageSize,
          cancellation: cancellation,
        )
      else
        Future.value(null),
      if (onlyDisplayName)
        useCase.execute(
          displayName: needle,
          page: page,
          pageSize: pageSize,
          cancellation: cancellation,
        )
      else
        Future.value(null),
    ]);

    final byUsername = responses[0];
    final byDisplayName = responses[1];

    // One side failing is only fatal if the other did too: half a result list
    // beats an error page.
    Failure? failure;
    var people = <ProfileEntity>[];
    var usernameHasNext = false;
    var displayNameHasNext = false;

    if (byUsername != null) {
      byUsername.match((f) => failure = f, (result) {
        people = _merge(people, result.items);
        usernameHasNext = result.hasNext;
      });
    }

    if (byDisplayName != null) {
      byDisplayName.match((f) => failure ??= f, (result) {
        failure = null;
        people = _merge(people, result.items);
        displayNameHasNext = result.hasNext;
      });
    }

    final error = failure;
    if (error != null && people.isEmpty) throw error;

    return PeopleSearchState(
      people: people,
      page: page,
      usernameHasNext: usernameHasNext,
      displayNameHasNext: displayNameHasNext,
    );
  }

  /// Username matches keep their place in front; nobody appears twice.
  static List<ProfileEntity> _merge(
    List<ProfileEntity> first,
    List<ProfileEntity> second,
  ) {
    final seen = {for (final profile in first) profile.id};

    return [
      ...first,
      ...second.where((profile) => seen.add(profile.id)),
    ];
  }
}

final peopleSearchProvider =
    AsyncNotifierProvider.family<
      PeopleSearchController,
      PeopleSearchState,
      String
    >(PeopleSearchController.new, isAutoDispose: true, retry: _neverRetry);

/// A search that failed shows an error with a retry on it rather than
/// quietly looping in the background: the reader is waiting on this one
/// answer, and a spinner that never resolves tells them nothing.
Duration? _neverRetry(int retryCount, Object error) => null;
