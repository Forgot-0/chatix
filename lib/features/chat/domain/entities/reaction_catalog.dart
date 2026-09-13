/// The emoji the server will accept as a reaction, and nothing else.
///
/// `PUT .../reactions/{emoji}/` answers `INVALID_REACTION` for anything
/// outside a curated list of ~73 emoji held server-side in
/// `app/chats/reactions/catalog.py` (api-docs §5.7.2). There is no endpoint
/// that publishes that list, so it is pinned here instead: the picker offers
/// this and only this, and a chat's own `allowed_reactions` narrows it
/// further.
///
/// Keeping it a single source on the client matters more than where it came
/// from — every surface that shows emoji (the quick bar, the full sheet, the
/// double-tap default) filters through [ReactionCatalog.isKnown], so a
/// mismatch with the server can only ever be fixed in one place.
library;

/// One drawer of the full-catalog sheet.
///
/// Sections partition the catalog: every emoji belongs to exactly one, and
/// together they are the whole of it, so the sheet can be built from the
/// sections alone without anything falling through.
enum ReactionSection {
  faces,
  people,
  hearts,
  celebration,
  food,
  nature,
  symbols,
}

/// The curated set, as the server holds it.
abstract final class ReactionCatalog {
  /// Faces — the bulk of the catalog.
  static const List<String> faces = [
    '😁',
    '🤣',
    '😍',
    '🥰',
    '😘',
    '😎',
    '🤗',
    '🤔',
    '🤨',
    '😐',
    '🥱',
    '🥴',
    '😴',
    '🤪',
    '🤓',
    '😇',
    '😈',
    '🤡',
    '🤩',
    '🤯',
    '😱',
    '😨',
    '😢',
    '😭',
    '😡',
    '🤬',
    '🤮',
    '💩',
    '👻',
    '👾',
    '🎃',
    '🗿',
  ];

  /// Hands, and the people they belong to.
  static const List<String> people = [
    '👍',
    '👎',
    '👏',
    '🙏',
    '👌',
    '🖕',
    '✍️',
    '🫡',
    '🤝',
    '🤷',
    '🤷‍♂️',
    '🤷‍♀️',
    '👨‍💻',
    '💅',
    '👀',
  ];

  static const List<String> hearts = ['❤️', '❤️‍🔥', '💔', '💘', '💋'];

  static const List<String> celebration = ['🎉', '🍾', '🏆', '🎅', '🎄', '☃️'];

  static const List<String> food = ['🍌', '🍓', '🌭'];

  static const List<String> nature = [
    '🔥',
    '⚡',
    '🌚',
    '🐳',
    '🦄',
    '🕊️',
    '🙈',
    '🙉',
    '🙊',
  ];

  static const List<String> symbols = ['💯', '🆒', '💊'];

  /// The sections in the order the sheet draws them.
  static const Map<ReactionSection, List<String>> sections = {
    ReactionSection.faces: faces,
    ReactionSection.people: people,
    ReactionSection.hearts: hearts,
    ReactionSection.celebration: celebration,
    ReactionSection.food: food,
    ReactionSection.nature: nature,
    ReactionSection.symbols: symbols,
  };

  /// Every accepted emoji, flattened, in section order.
  static const List<String> all = [
    ...faces,
    ...people,
    ...hearts,
    ...celebration,
    ...food,
    ...nature,
    ...symbols,
  ];

  /// What the quick bar falls back to before anyone has reacted to anything.
  ///
  /// Eight, because that is what fits across a phone without scrolling, and
  /// all eight are in [all] — a default the server would reject would make
  /// the first reaction a new reader ever sends the one that fails.
  static const List<String> quickDefaults = [
    '👍',
    '👎',
    '❤️',
    '🔥',
    '🥰',
    '👏',
    '😁',
    '🤔',
  ];

  /// How many emoji the quick bar shows before the "more" button.
  static const int quickBarLength = 8;

  static final Set<String> _index = all.toSet();

  /// Whether the server would accept this emoji at all, before chat settings.
  static bool isKnown(String emoji) => _index.contains(emoji);
}
