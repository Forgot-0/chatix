import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'
    show Category, CategoryEmoji;
import 'package:emoji_picker_flutter/locales/emoji_set_de.dart';
import 'package:emoji_picker_flutter/locales/emoji_set_en.dart';
import 'package:emoji_picker_flutter/locales/emoji_set_es.dart';
import 'package:emoji_picker_flutter/locales/emoji_set_fr.dart';
import 'package:emoji_picker_flutter/locales/emoji_set_ja.dart';
import 'package:emoji_picker_flutter/locales/emoji_set_ru.dart';

/// One drawer of the emoji panel, in the order the panel draws them.
enum EmojiGroup {
  smileys,
  animals,
  food,
  activities,
  travel,
  objects,
  symbols,
  flags;

  static EmojiGroup? _of(Category category) => switch (category) {
    Category.SMILEYS => smileys,
    Category.ANIMALS => animals,
    Category.FOODS => food,
    Category.ACTIVITIES => activities,
    Category.TRAVEL => travel,
    Category.OBJECTS => objects,
    Category.SYMBOLS => symbols,
    Category.FLAGS => flags,
    Category.RECENT => null,
  };
}

class EmojiSection {
  const EmojiSection(this.group, this.emojis);

  final EmojiGroup group;
  final List<String> emojis;
}

/// Every emoji a message can carry, grouped and searchable.
///
/// Unlike `ReactionCatalog` this is not a list the server curates: message
/// content is plain text (api-docs §5.4), so any emoji goes. The data comes
/// from `emoji_picker_flutter` — its Unicode set and, more to the point, its
/// search keywords in six of the seven languages the app speaks. Only the
/// data: the panel that draws it is the app's own.
///
/// Skin tones are not offered. Every emoji that has them is drawn in its
/// default yellow, which is also what the keywords describe.
abstract final class EmojiCatalog {
  /// The longest a search answer gets — four rows on a phone and more than
  /// anyone scrolls through before rephrasing.
  static const int searchLimit = 120;

  static List<EmojiSection>? _sections;

  /// The panel's drawers, in [EmojiGroup] order.
  static List<EmojiSection> get sections => _sections ??= _buildSections();

  static List<EmojiSection> _buildSections() {
    final byGroup = <EmojiGroup, List<String>>{};
    for (final category in emojiSetEnglish) {
      final group = EmojiGroup._of(category.category);
      if (group == null) continue;
      byGroup[group] = [for (final emoji in category.emoji) emoji.emoji];
    }

    // The data files a few emoji in two categories (an umbrella is weather
    // and clothing both). One home each, the first in panel order: a search
    // answer listing it twice reads like a bug.
    final seen = <String>{};
    return [
      for (final group in EmojiGroup.values)
        if ([
              for (final emoji in byGroup[group] ?? const <String>[])
                if (seen.add(emoji)) emoji,
            ]
            case final emojis when emojis.isNotEmpty)
          EmojiSection(group, List.unmodifiable(emojis)),
    ];
  }

  /// The keywords per emoji, per language — the reader's own and English,
  /// which is what people type for emoji whatever language they write in.
  static final Map<String, Map<String, List<String>>> _keywords = {};

  static Map<String, List<String>> _keywordsFor(String languageCode) {
    return _keywords.putIfAbsent(languageCode, () {
      final index = <String, List<String>>{};

      void absorb(List<CategoryEmoji> set) {
        for (final category in set) {
          for (final emoji in category.emoji) {
            (index[emoji.emoji] ??= <String>[]).addAll(
              emoji.keywords.map((keyword) => keyword.trim().toLowerCase()),
            );
          }
        }
      }

      absorb(emojiSetEnglish);
      final own = _localSet(languageCode);
      if (own != null) absorb(own);

      return index;
    });
  }

  /// The package's keywords for [languageCode], or null where it has none —
  /// Bengali among them, which then searches in English alone.
  static List<CategoryEmoji>? _localSet(String languageCode) =>
      switch (languageCode) {
        'ru' => emojiSetRussian,
        'de' => emojiSetGerman,
        'es' => emojiSetSpanish,
        'fr' => emojiSetFrance,
        'ja' => emojiSetJapanese,
        _ => null,
      };

  /// Emoji whose keywords match [query], best match first.
  ///
  /// A keyword that is the query beats one that starts with it, which beats
  /// one with a later word starting with it, which beats one merely
  /// containing it — so "cat" finds the cats before "cattle" and long before
  /// "communicate". Ties keep the panel's own order, so the answer reads like
  /// a slice of the grid rather than a shuffle.
  static List<String> search(
    String query, {
    required String languageCode,
    int limit = searchLimit,
  }) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const <String>[];

    final keywords = _keywordsFor(languageCode);
    final ranked = <({String emoji, int score, int order})>[];

    var order = 0;
    for (final section in sections) {
      for (final emoji in section.emojis) {
        final score = _scoreOf(keywords[emoji], needle);
        if (score != null) {
          ranked.add((emoji: emoji, score: score, order: order));
        }
        order++;
      }
    }

    ranked.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      return byScore != 0 ? byScore : a.order.compareTo(b.order);
    });

    return [for (final hit in ranked.take(limit)) hit.emoji];
  }

  static int? _scoreOf(List<String>? keywords, String needle) {
    if (keywords == null) return null;

    int? best;
    for (final keyword in keywords) {
      final score = keyword == needle
          ? 0
          : keyword.startsWith(needle)
          ? 1
          : keyword.contains(' $needle')
          ? 2
          // One letter inside a word matches half the catalog.
          : needle.length > 1 && keyword.contains(needle)
          ? 3
          : null;
      if (score != null && (best == null || score < best)) best = score;
      if (best == 0) break;
    }
    return best;
  }
}
