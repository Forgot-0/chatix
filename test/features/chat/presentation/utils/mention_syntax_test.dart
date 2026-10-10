import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/utils/mention_syntax.dart';
import 'package:chatix/features/chat/presentation/utils/message_linkifier.dart';

/// A mention is `@username` in plain text: what the composer writes has to
/// be exactly what the bubble finds again, and the list has to offer the
/// people an `@query` means.
void main() {
  ChatMemberEntity member(
    int id,
    String? username,
    String? name, {
    bool banned = false,
  }) => ChatMemberEntity(
    userId: id,
    roleId: ChatRole.member.id,
    isMuted: false,
    isBanned: banned,
    permissionsOverrides: const {},
    profile: ChatProfileEntity(
      userId: id,
      username: username,
      displayName: name,
      avatarUrl: null,
      avatarS3Key: null,
    ),
  );

  group('which usernames can be mentioned', () {
    test('letters, digits, dots, dashes and underscores read back', () {
      for (final username in ['ada', 'alan.turing', 'grace-h', 'ann_2', 'X1']) {
        expect(MentionSyntax.isMentionable(username), isTrue, reason: username);
      }
    });

    test('what the server allows but no pattern can end is left out', () {
      // api-docs §3.2 allows spaces, commas and apostrophes in a username.
      for (final username in [
        'john smith',
        "o'neil",
        'a,b',
        'ends.',
        '-dash',
        '.dot',
        '',
      ]) {
        expect(
          MentionSyntax.isMentionable(username),
          isFalse,
          reason: username,
        );
      }
      expect(MentionSyntax.isMentionable(null), isFalse);
    });
  });

  group('the format matches the bubble', () {
    for (final username in ['ada', 'alan.turing', 'grace-h', 'Ann_2']) {
      test('"$username" is found again as the same person', () {
        final inserted = MentionSyntax.insertionFor(username);
        expect(inserted, '@$username ');

        for (final content in [
          'hi ${inserted}look',
          '${inserted}look',
          'thanks $inserted'.trimRight(),
          'thanks @$username.',
          '(@$username)',
        ]) {
          final spans = MessageLinkifier.parse(
            content,
            isKnownMention: (handle) =>
                handle.toLowerCase() == username.toLowerCase(),
          );
          final mentions = spans
              .whereType<LinkSpan>()
              .where((span) => span.kind == MessageLinkKind.mention)
              .toList();

          expect(mentions, hasLength(1), reason: content);
          expect(mentions.single.target, username, reason: content);
          expect(mentions.single.text, '@$username', reason: content);
        }
      });
    }
  });

  group('the query being typed', () {
    TextEditingValue typed(String text, [int? caret]) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret ?? text.length),
    );

    test('an @ alone already asks', () {
      expect(
        MentionSyntax.queryAt(typed('hi @')),
        const MentionQuery(start: 3, end: 4, query: ''),
      );
    });

    test('runs from the @ to the caret', () {
      expect(
        MentionSyntax.queryAt(typed('ask @ad')),
        const MentionQuery(start: 4, end: 7, query: 'ad'),
      );
    });

    test('at the very start of the text', () {
      expect(MentionSyntax.queryAt(typed('@gr'))?.query, 'gr');
    });

    test('with the caret mid-word, the whole word is replaced', () {
      final query = MentionSyntax.queryAt(typed('@adele said', 3));

      expect(query, const MentionQuery(start: 0, end: 6, query: 'ad'));
    });

    test('a name in another alphabet is a query too', () {
      expect(MentionSyntax.queryAt(typed('спроси @Лин'))?.query, 'Лин');
    });

    test('an e-mail address is not a mention', () {
      expect(MentionSyntax.queryAt(typed('mail ann@exa')), isNull);
    });

    test('a finished mention followed by a space is not asked about', () {
      expect(MentionSyntax.queryAt(typed('@ada ')), isNull);
    });

    test('text without an @ is not a query', () {
      expect(MentionSyntax.queryAt(typed('nothing here')), isNull);
    });

    test('a selection is not a query', () {
      const value = TextEditingValue(
        text: '@ada',
        selection: TextSelection(baseOffset: 1, extentOffset: 4),
      );

      expect(MentionSyntax.queryAt(value), isNull);
    });
  });

  group('who the query could mean', () {
    final people = [
      member(7, 'me', 'Я'),
      member(42, 'ada', 'Ada Lovelace'),
      member(43, 'alan.turing', 'Alan Turing'),
      member(44, 'adele', 'Adele Goldberg'),
      member(45, 'grace', 'Grace Hopper'),
      member(46, 'linus', 'Линус Торвальдс'),
      member(47, 'nat', 'Natalia Alvarez'),
      member(48, 'john smith', 'John Smith'),
      member(49, 'mallory', 'Mallory', banned: true),
      member(50, null, 'Nobody'),
    ];

    List<String?> handles(String query) => [
      for (final m in mentionCandidates(people, query, myUserId: 7))
        m.profile?.username,
    ];

    test('the bare @ offers everyone who can be mentioned, by name', () {
      expect(handles(''), [
        'ada',
        'adele',
        'alan.turing',
        'grace',
        'nat',
        'linus',
      ]);
    });

    test('never the writer, the banned, or the unmentionable', () {
      final offered = handles('');

      expect(offered, isNot(contains('me')));
      expect(offered, isNot(contains('mallory')));
      expect(offered, isNot(contains('john smith')));
      expect(offered, isNot(contains(null)));
    });

    test('filters by username prefix', () {
      expect(handles('ad'), ['ada', 'adele']);
    });

    test('and by display name, whatever its case', () {
      expect(handles('GRA'), ['grace']);
      expect(handles('Лин'), ['linus']);
      expect(handles('лин'), ['linus']);
    });

    test('a later word of the name counts, after the first ones', () {
      expect(handles('tur'), ['alan.turing']);
      // Alan by his username, Natalia by her surname — the username first.
      expect(handles('al'), ['alan.turing', 'nat']);
    });

    test('a match inside a word comes last', () {
      expect(handles('ovel'), ['ada']);
    });

    test('a query nobody matches offers nobody', () {
      expect(handles('zz'), isEmpty);
    });

    test('a long roster is cut to the limit', () {
      final many = [
        for (var i = 0; i < 80; i++) member(100 + i, 'user$i', null),
      ];

      expect(
        mentionCandidates(many, 'user', myUserId: 7, limit: 20),
        hasLength(20),
      );
    });
  });
}
