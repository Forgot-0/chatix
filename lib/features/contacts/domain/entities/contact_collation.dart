import 'package:equatable/equatable.dart';

import 'package:chatix/features/contacts/domain/entities/contact.dart';

/// One letter of the book: its heading and the people under it.
class ContactSection extends Equatable {
  const ContactSection({required this.letter, required this.contacts});

  final String letter;
  final List<Contact> contacts;

  @override
  List<Object?> get props => [letter, contacts];
}

/// The alphabets the book is indexed by. Anything else is filed under
/// [ContactCollation.otherLetter].
enum ContactScript { latin, cyrillic, other }

/// How the book is sorted and cut into letters, for Russian and English.
///
/// Three rules a plain `compareTo` gets wrong:
///
/// * `Ё` sorts and files with `Е`, the way a Russian phone book does — by
///   code point it would come before `А`, and `ё` after `я`;
/// * accented Latin letters file under their base letter (`Émile` under E);
/// * the reader's own alphabet comes first: Cyrillic, then Latin for a
///   Russian reader, the other way round for everybody else, and the `#`
///   section — digits, emoji, other scripts — always last.
abstract final class ContactCollation {
  static const String otherLetter = '#';

  /// Languages whose readers expect Cyrillic sections first.
  static const Set<String> cyrillicFirst = {'ru', 'uk', 'be', 'bg', 'kk'};

  /// Characters skipped before the letter a name is filed under: a leading
  /// `@` on a handle, quotes and brackets around a nickname.
  static final RegExp _leadingNoise = RegExp(r'''^[\s@"'«»“”„‘’()\[\]{}]+''');

  static final RegExp _latin = RegExp('[a-z]');
  static final RegExp _cyrillic = RegExp('[а-я]');

  /// Folded one for one: each letter of [_foldFrom] becomes the letter at
  /// the same place in [_foldTo].
  static const String _foldFrom =
      'ёàáâãäåāąçćčďđèéêëēęěìíîïīłñńňòóôõöøōřśšťùúûüūůýÿźżž';
  static const String _foldTo =
      'еaaaaaaaacccddeeeeeeeiiiiilnnnooooooorsstuuuuuuyyzzz';

  /// Folded into two letters.
  static const Map<String, String> _ligatures = {
    'ß': 'ss',
    'æ': 'ae',
    'œ': 'oe',
  };

  static final Map<String, String> _folds = {
    for (var i = 0; i < _foldFrom.length; i++) _foldFrom[i]: _foldTo[i],
    ..._ligatures,
  };

  /// The name a contact is sorted and filed by — what its row is titled.
  static String nameOf(Contact contact) => contact.bestName ?? '';

  /// Lower case, accents and `ё` folded, leading noise dropped: the key two
  /// names are compared by first.
  static String keyOf(String name) {
    final lower = name.replaceFirst(_leadingNoise, '').toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_folds[char] ?? char);
    }
    return buffer.toString().trim();
  }

  /// The section heading [name] is filed under.
  static String letterOf(String name) {
    final key = keyOf(name);
    if (key.isEmpty) return otherLetter;

    final first = String.fromCharCode(key.runes.first);
    if (_latin.hasMatch(first) || _cyrillic.hasMatch(first)) {
      return first.toUpperCase();
    }
    return otherLetter;
  }

  static ContactScript scriptOf(String letter) {
    final lower = letter.toLowerCase();
    if (_latin.hasMatch(lower)) return ContactScript.latin;
    if (_cyrillic.hasMatch(lower)) return ContactScript.cyrillic;
    return ContactScript.other;
  }

  /// Where [script]'s sections go for a reader of [languageCode].
  static int rankOf(ContactScript script, {required String languageCode}) {
    final nativeCyrillic = cyrillicFirst.contains(languageCode);
    return switch (script) {
      ContactScript.cyrillic => nativeCyrillic ? 0 : 1,
      ContactScript.latin => nativeCyrillic ? 1 : 0,
      ContactScript.other => 2,
    };
  }

  static int compare(Contact a, Contact b, {required String languageCode}) =>
      _SortKey.of(
        a,
        languageCode: languageCode,
      ).compareTo(_SortKey.of(b, languageCode: languageCode));

  /// [contacts] in reading order. Each name is folded once, not once per
  /// comparison: a full book is five thousand of them.
  static List<Contact> sorted(
    Iterable<Contact> contacts, {
    required String languageCode,
  }) {
    final keyed = [
      for (final contact in contacts)
        _SortKey.of(contact, languageCode: languageCode),
    ]..sort((a, b) => a.compareTo(b));
    return [for (final key in keyed) key.contact];
  }

  /// [contacts] sorted and cut into lettered sections, in reading order.
  static List<ContactSection> sections(
    Iterable<Contact> contacts, {
    required String languageCode,
  }) {
    final sections = <ContactSection>[];
    String? letter;
    List<Contact>? bucket;

    for (final contact in sorted(contacts, languageCode: languageCode)) {
      final next = letterOf(nameOf(contact));
      if (next != letter) {
        if (letter != null) {
          sections.add(ContactSection(letter: letter, contacts: bucket!));
        }
        letter = next;
        bucket = <Contact>[];
      }
      bucket!.add(contact);
    }
    if (letter != null) {
      sections.add(ContactSection(letter: letter, contacts: bucket!));
    }
    return sections;
  }
}

/// Everything a contact is compared by, worked out once.
class _SortKey implements Comparable<_SortKey> {
  _SortKey._(this.contact, this.rank, this.key, this.lower);

  factory _SortKey.of(Contact contact, {required String languageCode}) {
    final name = ContactCollation.nameOf(contact);
    final rank = ContactCollation.rankOf(
      ContactCollation.scriptOf(ContactCollation.letterOf(name)),
      languageCode: languageCode,
    );
    return _SortKey._(
      contact,
      rank,
      ContactCollation.keyOf(name),
      name.toLowerCase(),
    );
  }

  final Contact contact;
  final int rank;
  final String key;
  final String lower;

  @override
  int compareTo(_SortKey other) {
    final byScript = rank.compareTo(other.rank);
    if (byScript != 0) return byScript;

    final byKey = key.compareTo(other.key);
    if (byKey != 0) return byKey;

    // Same letters: `е` before `ё`, then plain code order, then the id so
    // that two namesakes never swap places between rebuilds.
    final byName = lower.compareTo(other.lower);
    if (byName != 0) return byName;

    return contact.userId.compareTo(other.contact.userId);
  }
}

/// Finds contacts by what someone typed, the way the server's prefix search
/// does (api-docs §4.12) — but over the book on this device, so it answers on
/// every keystroke and without a connection.
abstract final class ContactMatcher {
  static final RegExp _boundary = RegExp(r'[\s\-_.]');

  /// Whether [contact] matches [query]: `@han` is a prefix of the handle;
  /// anything else is a prefix of a word — or of a run of words — in the
  /// local name, the display name or the handle.
  static bool matches(Contact contact, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;

    if (trimmed.startsWith('@')) {
      final handle = ContactCollation.keyOf(contact.username ?? '');
      final needle = ContactCollation.keyOf(trimmed);
      return needle.isNotEmpty && handle.startsWith(needle);
    }

    final needle = ContactCollation.keyOf(trimmed);
    if (needle.isEmpty) return false;

    final names = [
      contact.localName,
      contact.firstName,
      contact.lastName,
      contact.profile?.displayName,
      contact.username,
    ];
    for (final name in names) {
      if (name == null || name.isEmpty) continue;
      if (_startsAtWord(ContactCollation.keyOf(name), needle)) return true;
    }
    return false;
  }

  static bool _startsAtWord(String key, String needle) {
    for (var i = 0; i < key.length; i++) {
      final atWord = i == 0 || _boundary.hasMatch(key[i - 1]);
      if (atWord && key.startsWith(needle, i)) return true;
    }
    return false;
  }

  static List<Contact> filter(
    Iterable<Contact> contacts,
    String query, {
    required String languageCode,
  }) {
    return ContactCollation.sorted(
      contacts.where((contact) => matches(contact, query)),
      languageCode: languageCode,
    );
  }
}
