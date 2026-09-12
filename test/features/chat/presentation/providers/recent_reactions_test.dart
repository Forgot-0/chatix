import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/recent_reactions_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_picker.dart';

/// Which emoji someone reaches for is a habit, not chat data — there is no
/// endpoint that stores it, so it lives on the device and drives both the
/// quick bar's order and what a double tap sends.
void main() {
  ProviderContainer boot({List<String> stored = const []}) {
    final store = InMemoryChatLocalPrefsStore();
    if (stored.isNotEmpty) store.writeRecentReactions(stored);

    final container = ProviderContainer(
      overrides: [chatLocalPrefsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  RecentReactionsController notifierOf(ProviderContainer container) =>
      container.read(recentReactionsProvider.notifier);

  bool anything(String emoji) => true;

  group('remembering', () {
    test('the newest use goes to the front', () {
      final container = boot();
      final notifier = notifierOf(container);

      notifier.remember('👍');
      notifier.remember('🔥');

      expect(container.read(recentReactionsProvider), ['🔥', '👍']);
    });

    test('using one again moves it rather than repeating it', () {
      final container = boot();
      final notifier = notifierOf(container);

      notifier.remember('👍');
      notifier.remember('🔥');
      notifier.remember('👍');

      expect(container.read(recentReactionsProvider), ['👍', '🔥']);
    });

    test('the list stays short enough to aim at', () {
      final container = boot();
      final notifier = notifierOf(container);

      for (final emoji in ['1', '2', '3', '4', '5', '6', '7', '8']) {
        notifier.remember(emoji);
      }

      expect(
        container.read(recentReactionsProvider),
        hasLength(RecentReactionsController.maxRemembered),
      );
      expect(container.read(recentReactionsProvider).first, '8');
    });

    test('what was used last session comes back', () {
      final container = boot(stored: ['🎉', '😢']);

      expect(container.read(recentReactionsProvider), ['🎉', '😢']);
    });
  });

  group('the double-tap shortcut', () {
    // The gesture sends whatever the bar offers first.
    String? shortcutOf(ProviderContainer container, bool Function(String) ok) =>
        notifierOf(container).ordered(ok).firstOrNull;

    test('is the most recent emoji once there is one', () {
      final container = boot(stored: ['🔥']);

      expect(shortcutOf(container, anything), '🔥');
    });

    test('falls back to a default so it works before anyone reacts', () {
      final container = boot();

      expect(shortcutOf(container, anything), kQuickReactions.first);
    });

    test('skips a recent the chat does not allow', () {
      final container = boot(stored: ['🔥', '👍']);

      expect(shortcutOf(container, (emoji) => emoji == '👍'), '👍');
    });

    test('is null when the chat allows nothing', () {
      final container = boot(stored: ['🔥']);

      expect(shortcutOf(container, (_) => false), isNull);
    });
  });

  group('the quick bar order', () {
    test('puts recents first, then the rest of the defaults', () {
      final container = boot(stored: ['🎉']);

      final ordered = notifierOf(container).ordered(anything);

      expect(ordered.first, '🎉');
      expect(ordered.where((e) => e == '🎉'), hasLength(1));
      expect(ordered, containsAll(kQuickReactions));
    });

    test('drops everything the chat disallows', () {
      final container = boot(stored: ['🎉']);

      expect(
        notifierOf(container).ordered((emoji) => emoji == '👍'),
        ['👍'],
      );
    });

    test('an empty allow-list leaves no bar to draw', () {
      final container = boot(stored: ['🎉']);

      expect(notifierOf(container).ordered((_) => false), isEmpty);
    });
  });
}
