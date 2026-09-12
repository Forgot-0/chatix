import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/search_history_store.dart';
import 'package:chatix/features/chat/presentation/providers/search_history_provider.dart';
import 'package:chatix/features/chat/presentation/providers/search_providers.dart';

void main() {
  late InMemorySearchHistoryStore store;

  setUp(() => store = InMemorySearchHistoryStore());

  ProviderContainer boot() {
    final container = ProviderContainer(
      overrides: [searchHistoryStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('starts empty', () {
    expect(boot().read(searchHistoryProvider).isEmpty, isTrue);
  });

  test('a search someone acted on is remembered, newest first', () {
    final container = boot();
    final history = container.read(searchHistoryProvider.notifier);

    history.rememberQuery('design');
    history.rememberQuery('ann');

    expect(container.read(searchHistoryProvider).queries, ['ann', 'design']);
  });

  test('searching the same thing twice moves it up, not in twice', () {
    final container = boot();
    final history = container.read(searchHistoryProvider.notifier);

    history.rememberQuery('design');
    history.rememberQuery('ann');
    history.rememberQuery('DESIGN');

    expect(container.read(searchHistoryProvider).queries, ['DESIGN', 'ann']);
  });

  test('a single letter is on the way to a word, not a search', () {
    final container = boot();

    container.read(searchHistoryProvider.notifier).rememberQuery('a');

    expect(container.read(searchHistoryProvider).queries, isEmpty);
  });

  test('the list stops at its limit', () {
    final container = boot();
    final history = container.read(searchHistoryProvider.notifier);

    for (var i = 0; i < SearchHistoryController.maxQueries + 5; i++) {
      history.rememberQuery('query $i');
    }

    expect(
      container.read(searchHistoryProvider).queries,
      hasLength(SearchHistoryController.maxQueries),
    );
  });

  test('one search can be dropped, or all of them', () {
    final container = boot();
    final history = container.read(searchHistoryProvider.notifier);

    history.rememberQuery('design');
    history.rememberQuery('ann');

    history.removeQuery('design');
    expect(container.read(searchHistoryProvider).queries, ['ann']);

    history.clearQueries();
    expect(container.read(searchHistoryProvider).queries, isEmpty);
  });

  test('opened chats are remembered, newest first and without repeats', () {
    final container = boot();
    final history = container.read(searchHistoryProvider.notifier);

    history.rememberChat('a');
    history.rememberChat('b');
    history.rememberChat('a');

    expect(container.read(searchHistoryProvider).chatIds, ['a', 'b']);
  });

  test('a chat that is gone is dropped from the recents', () {
    final container = boot();
    final history = container.read(searchHistoryProvider.notifier);

    history.rememberChat('a');
    history.rememberChat('b');
    history.forgetChat('a');

    expect(container.read(searchHistoryProvider).chatIds, ['b']);
  });

  test('both lists survive into the next session', () async {
    final first = boot();
    first.read(searchHistoryProvider.notifier)
      ..rememberQuery('design')
      ..rememberChat('a');

    // The writes are fired off, not awaited, so let them land.
    await settle();

    final next = boot().read(searchHistoryProvider);
    expect(next.queries, ['design']);
    expect(next.chatIds, ['a']);
  });

  test('a store that cannot be built leaves the screen working', () {
    final container = ProviderContainer(
      overrides: [
        searchHistoryStoreProvider.overrideWith(
          (ref) => InMemorySearchHistoryStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(searchHistoryProvider).isEmpty, isTrue);
  });
}
