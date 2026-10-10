import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/composer_keyboard_provider.dart';

/// The emoji panel opens at the keyboard's last height, which this device
/// keeps between launches.
void main() {
  late InMemoryChatLocalPrefsStore store;

  ProviderContainer boot() {
    final container = ProviderContainer(
      overrides: [chatLocalPrefsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => store = InMemoryChatLocalPrefsStore());

  test('nothing is known before a keyboard has been seen', () {
    expect(boot().read(composerKeyboardHeightProvider), isNull);
  });

  test('remembers a keyboard, in whole pixels, and writes it down', () {
    final container = boot();

    container.read(composerKeyboardHeightProvider.notifier).remember(301.6);

    expect(container.read(composerKeyboardHeightProvider), 302);
    expect(store.readKeyboardHeight(), 302);
  });

  test('what was remembered last launch is where it starts', () async {
    await store.writeKeyboardHeight(336);

    expect(boot().read(composerKeyboardHeightProvider), 336);
  });

  test('a strip shorter than a keyboard is not one', () {
    final container = boot();

    container
        .read(composerKeyboardHeightProvider.notifier)
        .remember(EmojiPanelSizes.minKeyboard - 1);

    expect(container.read(composerKeyboardHeightProvider), isNull);
    expect(store.readKeyboardHeight(), isNull);
  });
}
