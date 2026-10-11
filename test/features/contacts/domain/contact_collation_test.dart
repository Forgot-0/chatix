import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_book.dart';
import 'package:chatix/features/contacts/domain/entities/contact_collation.dart';

import '../../../helpers/contacts_fixtures.dart';

/// The book is sorted and lettered the way a Russian or an English reader
/// expects their phone book to be.
void main() {
  List<String> names(Iterable<Contact> contacts) => [
    for (final c in contacts) c.bestName ?? '',
  ];

  Map<String, List<String>> lettered(
    Iterable<Contact> contacts, {
    required String languageCode,
  }) => {
    for (final section in ContactCollation.sections(
      contacts,
      languageCode: languageCode,
    ))
      section.letter: names(section.contacts),
  };

  final mixed = [
    contact(1, displayName: 'Борис'),
    contact(2, displayName: 'alice'),
    contact(3, displayName: 'Ёжик'),
    contact(4, displayName: 'Анна'),
    contact(5, displayName: 'Bob'),
    contact(6, displayName: '42 Pizza'),
    contact(7, displayName: 'Емеля'),
    contact(8, displayName: 'Яна'),
    contact(9, displayName: 'Zoe'),
    contact(10, displayName: '😀 Smile'),
  ];

  group('a Russian reader', () {
    test('sees Cyrillic first, then Latin, then #', () {
      expect(lettered(mixed, languageCode: 'ru'), {
        'А': ['Анна'],
        'Б': ['Борис'],
        'Е': ['Ёжик', 'Емеля'],
        'Я': ['Яна'],
        'A': ['alice'],
        'B': ['Bob'],
        'Z': ['Zoe'],
        '#': ['42 Pizza', '😀 Smile'],
      });
      expect(
        ContactCollation.sections(
          mixed,
          languageCode: 'ru',
        ).map((s) => s.letter),
        ['А', 'Б', 'Е', 'Я', 'A', 'B', 'Z', '#'],
      );
    });

    test('files Ё under Е and sorts it as Е, not before А or after Я', () {
      final sorted = ContactCollation.sorted([
        contact(1, displayName: 'Яков'),
        contact(2, displayName: 'Ёлка'),
        contact(3, displayName: 'Ежевика'),
        contact(4, displayName: 'Алла'),
        contact(5, displayName: 'Ель'),
      ], languageCode: 'ru');

      expect(names(sorted), ['Алла', 'Ежевика', 'Ёлка', 'Ель', 'Яков']);
      expect(ContactCollation.letterOf('Ёлка'), 'Е');
    });

    test('puts е before ё when the words are otherwise the same', () {
      final sorted = ContactCollation.sorted([
        contact(1, displayName: 'Ёжик'),
        contact(2, displayName: 'Ежик'),
      ], languageCode: 'ru');

      expect(names(sorted), ['Ежик', 'Ёжик']);
    });

    test('keeps Й as a letter of its own, after И', () {
      final sorted = ContactCollation.sorted([
        contact(1, displayName: 'Йод'),
        contact(2, displayName: 'Иван'),
        contact(3, displayName: 'Катя'),
      ], languageCode: 'ru');

      expect(names(sorted), ['Иван', 'Йод', 'Катя']);
      expect(ContactCollation.letterOf('Йод'), 'Й');
    });
  });

  group('an English reader', () {
    test('sees Latin first, then Cyrillic, then #', () {
      expect(
        ContactCollation.sections(
          mixed,
          languageCode: 'en',
        ).map((s) => s.letter),
        ['A', 'B', 'Z', 'А', 'Б', 'Е', 'Я', '#'],
      );
    });

    test('ignores case and accents: Émile is an E, between Eve and Frank', () {
      final sorted = ContactCollation.sorted([
        contact(1, displayName: 'frank'),
        contact(2, displayName: 'Émile'),
        contact(3, displayName: 'Eve'),
        contact(4, displayName: 'eva'),
      ], languageCode: 'en');

      expect(names(sorted), ['Émile', 'eva', 'Eve', 'frank']);
      expect(ContactCollation.letterOf('Émile'), 'E');
      expect(ContactCollation.letterOf('Øystein'), 'O');
      expect(ContactCollation.keyOf('Straße'), 'strasse');
    });

    test('other languages read like English', () {
      expect(
        ContactCollation.rankOf(ContactScript.latin, languageCode: 'de'),
        lessThan(
          ContactCollation.rankOf(ContactScript.cyrillic, languageCode: 'de'),
        ),
      );
    });
  });

  group('what a contact is filed under', () {
    test('the local name first, then the display name, then the handle', () {
      final renamed = contact(1, displayName: 'Zed', firstName: 'Аня');
      final handleOnly = contact(2, username: 'boris');
      final noProfile = contact(3, withProfile: false);

      expect(ContactCollation.letterOf(ContactCollation.nameOf(renamed)), 'А');
      // `@boris`: the @ is skipped, the handle is filed under B.
      expect(
        ContactCollation.letterOf(ContactCollation.nameOf(handleOnly)),
        'B',
      );
      expect(
        ContactCollation.letterOf(ContactCollation.nameOf(noProfile)),
        ContactCollation.otherLetter,
      );
    });

    test('skips quotes and brackets around a nickname', () {
      expect(ContactCollation.letterOf('«Мама»'), 'М');
      expect(ContactCollation.letterOf('"Doc"'), 'D');
      expect(ContactCollation.letterOf('(Work) Ann'), 'W');
    });

    test('namesakes keep a stable order, by id', () {
      final sorted = ContactCollation.sorted([
        contact(9, displayName: 'Ann'),
        contact(3, displayName: 'Ann'),
        contact(5, displayName: 'Ann'),
      ], languageCode: 'en');

      expect([for (final c in sorted) c.userId], [3, 5, 9]);
    });
  });

  group('the book', () {
    test('lists favourites in the same order as everybody else', () {
      final book = ContactBook([
        contact(1, displayName: 'Яна', isFavorite: true),
        contact(2, displayName: 'Анна', isFavorite: true),
        contact(3, displayName: 'Борис'),
      ]);

      expect(names(book.favorites(languageCode: 'ru')), ['Анна', 'Яна']);
      // Favourites stay in the alphabet as well.
      expect(
        book.sections(languageCode: 'ru').expand((s) => s.contacts).length,
        3,
      );
    });

    test('knows the local name of a contact, and nothing of strangers', () {
      final book = ContactBook([
        contact(1, displayName: 'Ivan Petrov', firstName: 'Ваня'),
        contact(2, displayName: 'Anna'),
      ]);

      expect(book.localNameOf(1), 'Ваня');
      expect(book.localNameOf(2), isNull);
      expect(book.localNameOf(99), isNull);
    });
  });

  group('matching what was typed', () {
    final ivan = contact(
      1,
      displayName: 'Ivan Petrov',
      username: 'ivan_dev',
      firstName: 'Ваня',
      lastName: 'Работа',
    );

    test('a prefix of any word of any name', () {
      for (final query in ['iv', 'pet', 'Ivan P', 'ван', 'раб', 'Ваня Раб']) {
        expect(ContactMatcher.matches(ivan, query), isTrue, reason: query);
      }
    });

    test('not the middle of a word', () {
      for (final query in ['van', 'trov', 'аня']) {
        expect(ContactMatcher.matches(ivan, query), isFalse, reason: query);
      }
    });

    test('@ looks at the handle only', () {
      expect(ContactMatcher.matches(ivan, '@ivan'), isTrue);
      expect(ContactMatcher.matches(ivan, '@dev'), isFalse);
      expect(ContactMatcher.matches(ivan, '@petrov'), isFalse);
    });

    test('ё and е find each other', () {
      final fedor = contact(2, displayName: 'Фёдор');
      expect(ContactMatcher.matches(fedor, 'федор'), isTrue);
      expect(ContactMatcher.matches(fedor, 'Фёд'), isTrue);
    });
  });
}
