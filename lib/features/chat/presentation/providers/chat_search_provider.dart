import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_search.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/domain/usecases/search_messages_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/search_providers.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
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

  final chats =
      ref.watch(chatListProvider).value?.items ?? const <ChatEntity>[];

  return searchLoadedChats(
    chats,
    query,
    myUserId: ref.watch(authProvider.select((user) => user.value?.id)),
  );
});

/// A page of message hits.
class MessageSearchState extends Equatable {
  const MessageSearchState({
    this.hits = const <MessageSearchHit>[],
    this.source = MessageSearchSource.server,
    this.hasNext = false,
    this.nextMessageId,
    this.isLoadingMore = false,
  });

  final List<MessageSearchHit> hits;

  /// Whether the whole history was searched, or only what is on the device.
  final MessageSearchSource source;

  final bool hasNext;
  final String? nextMessageId;
  final bool isLoadingMore;

  bool get isEmpty => hits.isEmpty;

  bool get isLocal => source == MessageSearchSource.localCache;

  bool get canLoadMore => hasNext && nextMessageId != null;

  MessageSearchState copyWith({
    List<MessageSearchHit>? hits,
    MessageSearchSource? source,
    bool? hasNext,
    String? nextMessageId,
    bool? isLoadingMore,
  }) {
    return MessageSearchState(
      hits: hits ?? this.hits,
      source: source ?? this.source,
      hasNext: hasNext ?? this.hasNext,
      nextMessageId: nextMessageId ?? this.nextMessageId,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    hits,
    source,
    hasNext,
    nextMessageId,
    isLoadingMore,
  ];
}

/// Messages matching the query, from `GET /chats/messages/search/`.
///
/// The server searches every chat the caller is still in, so this is not
/// limited to what has been opened on this device — but the cache is kept
/// fed anyway, because it is what answers when the request cannot be made.
class MessageSearchController extends AsyncNotifier<MessageSearchState> {
  MessageSearchController(this._query);

  final String _query;

  @override
  Future<MessageSearchState> build() async {
    final needle = _query.trim();
    if (needle.length < SearchMessagesUseCase.minQueryLength) {
      return const MessageSearchState();
    }

    _seedCacheFromList();

    final cancellation = RequestCancellation();
    ref.onDispose(cancellation.cancel);

    return _fetch(needle, cancellation: cancellation);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.canLoadMore || current.isLoadingMore) {
      return;
    }

    // The cache has no cursor to continue from; an offline result is one
    // page and says as much by having nothing to load.
    if (current.isLocal) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final cancellation = RequestCancellation();
    ref.onDispose(cancellation.cancel);

    final next = await _fetch(
      _query.trim(),
      lastMessageId: current.nextMessageId,
      cancellation: cancellation,
    ).onError<Failure>((failure, _) {
      Logger.warning('MessageSearch: next page failed (${failure.message})');
      return current.copyWith(isLoadingMore: false);
    });

    if (!ref.mounted) return;

    final latest = state.value ?? current;
    state = AsyncValue.data(
      latest.copyWith(
        hits: [...latest.hits, ...next.hits],
        source: next.source,
        hasNext: next.hasNext,
        nextMessageId: next.nextMessageId,
        isLoadingMore: false,
      ),
    );
  }

  Future<MessageSearchState> _fetch(
    String needle, {
    String? lastMessageId,
    required RequestCancellation cancellation,
  }) async {
    final result = await ref
        .read(searchMessagesUseCaseProvider)
        .execute(
          needle,
          lastMessageId: lastMessageId,
          cancellation: cancellation,
        );

    return result.match((failure) => throw failure, (found) {
      return MessageSearchState(
        hits: found.hits,
        source: found.source,
        hasNext: found.hasNext,
        nextMessageId: found.nextMessageId,
      );
    });
  }

  /// Keeps the offline fallback worth having: every chat row carries its own
  /// `last_message` (api-docs §5.2), so the newest message of every chat is
  /// searchable even on a device that has opened none of them.
  void _seedCacheFromList() {
    if (!ref.exists(chatListProvider)) return;

    final store = ref.read(messageCacheStoreProvider);
    for (final chat in ref.read(chatListProvider).value?.items ??
        const <ChatEntity>[]) {
      final last = chat.lastMessage;
      if (last != null) store.remember(chat.id, [last]);
    }
  }
}

final messageSearchProvider =
    AsyncNotifierProvider.family<
      MessageSearchController,
      MessageSearchState,
      String
    >(MessageSearchController.new, isAutoDispose: true, retry: _neverRetry);

/// A page of people.
class PeopleSearchState extends Equatable {
  const PeopleSearchState({
    this.people = const <ProfileEntity>[],
    this.page = 1,
    this.hasNext = false,
    this.isLoadingMore = false,
  });

  final List<ProfileEntity> people;

  final int page;

  /// `PageResult` carries no `has_next`; it is `page < ceil(total/page_size)`
  /// (api-docs §1.5), which the model works out.
  final bool hasNext;

  final bool isLoadingMore;

  bool get isEmpty => people.isEmpty;

  PeopleSearchState copyWith({
    List<ProfileEntity>? people,
    int? page,
    bool? hasNext,
    bool? isLoadingMore,
  }) {
    return PeopleSearchState(
      people: people ?? this.people,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [people, page, hasNext, isLoadingMore];
}

/// People matching the query, from `GET /profiles/`.
///
/// One request per search: `q` matches `username` OR `display_name` on the
/// server (api-docs §4.2), so there is nothing left for the client to merge.
/// The endpoint takes a token and 20 requests a minute, which the debounce
/// on the field is what keeps this inside.
///
/// Keyed by the query: the moment a new one arrives this instance is
/// disposed, which cancels whatever was still in flight.
class PeopleSearchController extends AsyncNotifier<PeopleSearchState> {
  PeopleSearchController(this._query);

  static const int pageSize = 20;

  /// Shorter than this and the server answers 422, so the screen does not
  /// ask at all.
  static const int minQueryLength = GetProfilesUseCase.minQueryLength;

  final String _query;

  @override
  Future<PeopleSearchState> build() async {
    final needle = _query.trim();
    if (needle.length < minQueryLength) return const PeopleSearchState();

    final cancellation = RequestCancellation();
    ref.onDispose(cancellation.cancel);

    return _fetch(needle, page: 1, cancellation: cancellation);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.isLoadingMore) return;

    final needle = _query.trim();
    if (needle.length < minQueryLength) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final cancellation = RequestCancellation();
    ref.onDispose(cancellation.cancel);

    final next = await _fetch(
      needle,
      page: current.page + 1,
      cancellation: cancellation,
    );

    if (!ref.mounted) return;

    final latest = state.value ?? current;
    state = AsyncValue.data(
      latest.copyWith(
        people: _merge(latest.people, next.people),
        page: next.page,
        hasNext: next.hasNext,
        isLoadingMore: false,
      ),
    );
  }

  Future<PeopleSearchState> _fetch(
    String needle, {
    required int page,
    required RequestCancellation cancellation,
  }) async {
    final result = await ref
        .read(getProfilesUseCaseProvider)
        .execute(
          q: needle,
          page: page,
          pageSize: pageSize,
          cancellation: cancellation,
        );

    return result.match((failure) => throw failure, (found) {
      return PeopleSearchState(
        people: found.items,
        page: found.page,
        hasNext: found.hasNext,
      );
    });
  }

  /// Nobody appears twice, even if a page boundary moved under us.
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
