import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/domain/entities/reaction_catalog.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';

/// The emoji this person actually uses, most recent first.
///
/// Two things read it: the quick-reaction bar orders itself by it, and the
/// double-tap shortcut sends whichever is at the front. Before anyone has
/// reacted to anything it falls back to the default set, so the shortcut
/// works on day one rather than doing nothing until primed.
class RecentReactionsController extends Notifier<List<String>> {
  /// A row someone can aim at, and the same eight the quick bar shows — a
  /// longer memory would only ever surface through the full catalog, which
  /// has its own order.
  static const int maxRemembered = ReactionCatalog.quickBarLength;

  @override
  List<String> build() {
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
