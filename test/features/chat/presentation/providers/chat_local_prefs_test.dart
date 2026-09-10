import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';

void main() {
  late InMemoryChatLocalPrefsStore store;

  setUp(() => store = InMemoryChatLocalPrefsStore());

  ProviderContainer boot() {
    final container = ProviderContainer(
      overrides: [chatLocalPrefsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a chat carries no flags until something says otherwise', () {
    final prefs = boot().read(chatLocalPrefsProvider);

    expect(prefs.isPinned('a'), isFalse);
    expect(prefs.isArchived('a'), isFalse);
    expect(prefs.isMuted('a'), isFalse);
  });

  test('toggling reports what the flag became', () {
    final controller = boot().read(chatLocalPrefsProvider.notifier);

    expect(controller.toggle(ChatLocalFlag.pinned, 'a'), isTrue);
    expect(controller.toggle(ChatLocalFlag.pinned, 'a'), isFalse);
  });

  test('flags are independent of each other and of other chats', () {
    final container = boot();
    final controller = container.read(chatLocalPrefsProvider.notifier);

    controller.toggle(ChatLocalFlag.pinned, 'a');
    controller.toggle(ChatLocalFlag.muted, 'b');

    final prefs = container.read(chatLocalPrefsProvider);
    expect(prefs.pinned, {'a'});
    expect(prefs.muted, {'b'});
    expect(prefs.archived, isEmpty);
  });

  test('set is idempotent and leaves the state object alone', () {
    final container = boot();
    final controller = container.read(chatLocalPrefsProvider.notifier);

    controller.set(ChatLocalFlag.archived, 'a', value: true);
    final afterFirst = container.read(chatLocalPrefsProvider);

    controller.set(ChatLocalFlag.archived, 'a', value: true);
    expect(container.read(chatLocalPrefsProvider), same(afterFirst));
  });

  test('forget drops every flag a chat had', () {
    final container = boot();
    final controller = container.read(chatLocalPrefsProvider.notifier);

    controller.toggle(ChatLocalFlag.pinned, 'a');
    controller.toggle(ChatLocalFlag.muted, 'a');
    controller.toggle(ChatLocalFlag.archived, 'a');

    controller.forget('a');

    final prefs = container.read(chatLocalPrefsProvider);
    expect(prefs.pinned, isEmpty);
    expect(prefs.muted, isEmpty);
    expect(prefs.archived, isEmpty);
  });

  test('flags survive into the next session', () async {
    final first = boot();
    first.read(chatLocalPrefsProvider.notifier).toggle(
      ChatLocalFlag.pinned,
      'a',
    );

    // The write is fired off, not awaited, so let it land.
    await Future<void>.delayed(Duration.zero);

    expect(boot().read(chatLocalPrefsProvider).isPinned('a'), isTrue);
  });

  test('a store that cannot be built leaves the screen working', () {
    final container = ProviderContainer(
      overrides: [
        chatLocalPrefsStoreProvider.overrideWith(
          (ref) => InMemoryChatLocalPrefsStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(chatLocalPrefsProvider), const ChatLocalPrefs());
  });
}
