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

    expect(prefs.isMuted('a'), isFalse);
  });

  test('toggling reports what the flag became', () {
    final controller = boot().read(chatLocalPrefsProvider.notifier);

    expect(controller.toggle(ChatLocalFlag.muted, 'a'), isTrue);
    expect(controller.toggle(ChatLocalFlag.muted, 'a'), isFalse);
  });

  test('flags are independent between chats', () {
    final container = boot();
    final controller = container.read(chatLocalPrefsProvider.notifier);

    controller.toggle(ChatLocalFlag.muted, 'b');

    final prefs = container.read(chatLocalPrefsProvider);
    expect(prefs.muted, {'b'});
    expect(prefs.isMuted('a'), isFalse);
  });

  test('set is idempotent and leaves the state object alone', () {
    final container = boot();
    final controller = container.read(chatLocalPrefsProvider.notifier);

    controller.set(ChatLocalFlag.muted, 'a', value: true);
    final afterFirst = container.read(chatLocalPrefsProvider);

    controller.set(ChatLocalFlag.muted, 'a', value: true);
    expect(container.read(chatLocalPrefsProvider), same(afterFirst));
  });

  test('forget drops every flag a chat had', () {
    final container = boot();
    final controller = container.read(chatLocalPrefsProvider.notifier);

    controller.toggle(ChatLocalFlag.muted, 'a');
    controller.forget('a');

    expect(container.read(chatLocalPrefsProvider).muted, isEmpty);
  });

  test('flags survive into the next session', () async {
    final first = boot();
    first.read(chatLocalPrefsProvider.notifier).toggle(
      ChatLocalFlag.muted,
      'a',
    );

    // The write is fired off, not awaited, so let it land.
    await Future<void>.delayed(Duration.zero);

    expect(boot().read(chatLocalPrefsProvider).isMuted('a'), isTrue);
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
