import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_picker.dart';

/// The emoji this person actually uses, most recent first.
///
/// Two things read it: the quick-reaction bar orders itself by it, and the
/// double-tap shortcut sends whichever is at the front. Before anyone has
/// reacted to anything it falls back to the default set, so the shortcut
/// works on day one rather than doing nothing until primed.
class RecentReactionsController extends Notifier<List<String>> {
  /// A row of a handful is a row someone can aim at; a row of thirty is a
  /// scroll.
  static const int maxRemembered = 6;

  @override
  List<String> build() {
    final stored = ref
        .watch(chatLocalPrefsStoreProvider)
        .readRecentReactions();

    return stored.isEmpty
        ? const <String>[]
        : stored.take(maxRemembered).toList();
  }

  /// The quick-reaction bar's order: recents first, then the rest of the
  /// defaults, with nothing repeated.
  ///
  /// The front of this list is also what a double tap sends, which is what
  /// makes the gesture match the habit instead of a fixed default. An empty
  /// result means the chat allows no emoji at all, and the gesture does
  /// nothing.
  List<String> ordered(bool Function(String emoji) isAllowed) => [
    for (final emoji in state)
      if (isAllowed(emoji)) emoji,
    for (final emoji in kQuickReactions)
      if (isAllowed(emoji) && !state.contains(emoji)) emoji,
  ];

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
              'Chat prefs: recent reactions not persisted ($error)',
            ),
          ),
    );
  }
}

final recentReactionsProvider =
    NotifierProvider<RecentReactionsController, List<String>>(
      RecentReactionsController.new,
    );
