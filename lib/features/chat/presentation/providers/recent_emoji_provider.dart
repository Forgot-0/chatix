import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/domain/entities/reaction_catalog.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';

/// The emoji this person actually uses, most recent first — one history for
/// the whole app.
///
/// Three things read it: the composer's emoji panel opens on it, the
/// quick-reaction bar orders itself by it, and the double-tap shortcut sends
/// whichever allowed one is at the front. An emoji typed into a message and
/// one put on a message are the same habit, so both land here; the reaction
/// surfaces filter it through the chat's policy, which already drops anything
/// outside the server's catalog (api-docs §5.7.2).
///
/// Before anyone has used anything the reaction bar falls back to the
/// default set, so the shortcut works on day one rather than doing nothing
/// until primed.
class RecentEmojiController extends Notifier<List<String>> {
  /// Five rows of the emoji panel. The quick bar only ever takes the first
  /// [ReactionCatalog.quickBarLength] that a chat allows, so a longer memory
  /// costs it nothing and keeps a reaction from being pushed out by a burst
  /// of typing.
  static const int maxRemembered = 40;

  @override
  List<String> build() {
    // Still the key the reaction-only history was kept under: that history
    // is where this one starts.
    final stored = ref.watch(chatLocalPrefsStoreProvider).readRecentReactions();

    return stored.isEmpty
        ? const <String>[]
        : stored.take(maxRemembered).toList();
  }

  /// The quick-reaction bar's order: recents first, then the rest of the
  /// defaults, with nothing repeated and never more than the bar can hold.
  ///
  /// The front of this list is also what a double tap sends, which is what
  /// makes the gesture match the habit instead of a fixed default. An empty
  /// result means the chat allows no emoji at all, and the gesture does
  /// nothing.
  List<String> ordered(bool Function(String emoji) isAllowed) => [
    for (final emoji in state)
      if (isAllowed(emoji)) emoji,
    for (final emoji in ReactionCatalog.quickDefaults)
      if (isAllowed(emoji) && !state.contains(emoji)) emoji,
  ].take(ReactionCatalog.quickBarLength).toList();

  void remember(String emoji) {
    if (emoji.isEmpty) return;
    if (state.firstOrNull == emoji) return;

    final next = [
      emoji,
      ...state.where((e) => e != emoji),
    ].take(maxRemembered).toList();

    state = next;

    unawaited(
      ref
          .read(chatLocalPrefsStoreProvider)
          .writeRecentReactions(next)
          .catchError(
            (Object error) => Logger.warning(
              'Chat prefs: recent emoji not persisted ($error)',
            ),
          ),
    );
  }
}

final recentEmojiProvider =
    NotifierProvider<RecentEmojiController, List<String>>(
      RecentEmojiController.new,
    );
