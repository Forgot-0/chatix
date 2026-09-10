import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/presentation/providers/chat_drafts_provider.dart';
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

  test('a draft is trimmed and readable by chat', () {
    final container = boot();
    container.read(chatDraftsProvider.notifier).save('a', '  see you  ');

    expect(container.read(chatDraftProvider('a')), 'see you');
  });

  test('blank text is not a draft', () {
    final container = boot();
    final drafts = container.read(chatDraftsProvider.notifier);

    drafts.save('a', 'hello');
    drafts.save('a', '   ');

    expect(container.read(chatDraftProvider('a')), isNull);
  });

  test('clearing one chat leaves the others alone', () {
    final container = boot();
    final drafts = container.read(chatDraftsProvider.notifier);

    drafts.save('a', 'one');
    drafts.save('b', 'two');
    drafts.clear('a');

    expect(container.read(chatDraftProvider('a')), isNull);
    expect(container.read(chatDraftProvider('b')), 'two');
  });

  test('a draft outlives the session it was typed in', () async {
    final container = boot();
    container.read(chatDraftsProvider.notifier).save('a', 'unsent');
    await container.read(chatDraftsProvider.notifier).flush();

    expect(boot().read(chatDraftProvider('a')), 'unsent');
  });

  test('a cleared draft is gone from storage too', () async {
    final first = boot();
    first.read(chatDraftsProvider.notifier).save('a', 'unsent');
    await first.read(chatDraftsProvider.notifier).flush();

    final second = boot();
    second.read(chatDraftsProvider.notifier).clear('a');
    await second.read(chatDraftsProvider.notifier).flush();

    expect(boot().read(chatDraftProvider('a')), isNull);
  });

  test('the debounced write lands without a flush', () async {
    final container = boot();
    container.read(chatDraftsProvider.notifier).save('a', 'unsent');

    await Future<void>.delayed(
      ChatDraftsController.writeDelay + const Duration(milliseconds: 50),
    );

    expect(boot().read(chatDraftProvider('a')), 'unsent');
  });
}
