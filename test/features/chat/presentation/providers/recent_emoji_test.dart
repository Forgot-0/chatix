import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/domain/entities/reaction_catalog.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/recent_emoji_provider.dart';

/// Which emoji someone reaches for is a habit, not chat data — there is no
/// endpoint that stores it, so it lives on the device. One history for the
/// whole app: the composer's emoji panel opens on it, and it drives both the
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

  RecentEmojiController notifierOf(ProviderContainer container) =>
      container.read(recentEmojiProvider.notifier);

  bool anything(String emoji) => true;

  group('remembering', () {
    test('the newest use goes to the front', () {
      final container = boot();
      final notifier = notifierOf(container);

      notifier.remember('👍');
      notifier.remember('🔥');

      expect(container.read(recentEmojiProvider), ['🔥', '👍']);
    });

    test('using one again moves it rather than repeating it', () {
      final container = boot();
      final notifier = notifierOf(container);

      notifier.remember('👍');
      notifier.remember('🔥');
      notifier.remember('👍');

      expect(container.read(recentEmojiProvider), ['👍', '🔥']);
    });

    test('the list stays short enough to aim at', () {
      final container = boot();
      final notifier = notifierOf(container);

      final used = [
        for (var i = 0; i < RecentEmojiController.maxRemembered + 5; i++) '$i',
      ];
      used.forEach(notifier.remember);

      expect(
        container.read(recentEmojiProvider),
        hasLength(RecentEmojiController.maxRemembered),
      );
      expect(container.read(recentEmojiProvider).first, used.last);
    });

    test('remembers more than the quick bar shows, for the emoji panel', () {
      expect(
        RecentEmojiController.maxRemembered,
        greaterThan(ReactionCatalog.quickBarLength),
      );
    });

    test('what was used last session comes back', () {
      final container = boot(stored: ['🎉', '😢']);

      expect(container.read(recentEmojiProvider), ['🎉', '😢']);
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

      expect(
        shortcutOf(container, anything),
        ReactionCatalog.quickDefaults.first,
      );
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
      // Everything the bar still has room for after the recent, in order.
      expect(
        ordered.skip(1),
        ReactionCatalog.quickDefaults.take(ReactionCatalog.quickBarLength - 1),
      );
    });

    test('never offers more than the bar can hold', () {
      final container = boot(stored: ['🎉', '😢', '💯']);

      expect(
        notifierOf(container).ordered(anything),
        hasLength(ReactionCatalog.quickBarLength),
      );
    });

    test('offers only what the server would accept', () {
      // A recent stored by an older build, or by a catalog that has since
      // changed, would come back INVALID_REACTION.
      final container = boot(stored: ['🫠', '🔥']);

      expect(
        notifierOf(container).ordered(ReactionCatalog.isKnown),
        isNot(contains('🫠')),
      );
    });

    test('an emoji typed into a message never reaches the bar if the '
        'server would refuse it as a reaction', () {
      final container = boot();
      final notifier = notifierOf(container);

      // Typed from the composer's panel: fine in a message, not a reaction.
      notifier.remember('🫠');
      notifier.remember('🔥');
      notifier.remember('🧑‍🚀');

      expect(container.read(recentEmojiProvider), ['🧑‍🚀', '🔥', '🫠']);
      expect(
        notifierOf(container).ordered(ReactionCatalog.isKnown),
        allOf(contains('🔥'), isNot(contains('🫠')), isNot(contains('🧑‍🚀'))),
      );
      expect(
        notifierOf(container).ordered(ReactionCatalog.isKnown).first,
        '🔥',
      );
    });

    test('drops everything the chat disallows', () {
      final container = boot(stored: ['🎉']);

      expect(notifierOf(container).ordered((emoji) => emoji == '👍'), ['👍']);
    });

    test('an empty allow-list leaves no bar to draw', () {
      final container = boot(stored: ['🎉']);

      expect(notifierOf(container).ordered((_) => false), isEmpty);
    });
  });
}
