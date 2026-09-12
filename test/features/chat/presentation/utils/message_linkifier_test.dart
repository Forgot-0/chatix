import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/presentation/utils/message_linkifier.dart';

/// Message content comes back exactly as it was typed, with no HTML escaping
/// (api-docs §5.4). These tests pin down the only enrichment the client does
/// to it: finding spans worth tapping, and leaving every character alone.
void main() {
  List<MessageSpan> parse(String content, {Set<String> members = const {}}) =>
      MessageLinkifier.parse(
        content,
        isKnownMention: (handle) =>
            members.any((m) => m.toLowerCase() == handle.toLowerCase()),
      );

  List<LinkSpan> linksIn(String content, {Set<String> members = const {}}) =>
      parse(content, members: members).whereType<LinkSpan>().toList();

  String rejoin(List<MessageSpan> spans) =>
      spans.map((span) => span.text).join();

  group('nothing is lost or rewritten', () {
    test('every character comes back in order', () {
      const content =
          'See https://example.com/a_(b) and mail me@example.com, '
          'ping @ada or +1 (555) 010-9999 — ok?';

      expect(rejoin(parse(content, members: {'ada'})), content);
    });

    test('markup is text, not markup', () {
      // The server stores `<`, `&` and `"` verbatim. Anything that treats
      // this as a document hands the author the reader's screen.
      const content = '<script>alert("x")</script> & <b>bold</b>';
      final spans = parse(content);

      expect(spans, [const PlainSpan(content)]);
      expect(rejoin(spans), content);
    });

    test('a url inside an angle bracket does not swallow the bracket', () {
      final links = linksIn('read <https://example.com> now');

      expect(links.single.text, 'https://example.com');
    });

    test('empty content yields one empty plain span', () {
      expect(MessageLinkifier.parse(''), [const PlainSpan('')]);
    });

    test('plain text yields one span, not one per word', () {
      expect(parse('just some words').length, 1);
    });
  });

  group('urls', () {
    test('http and https are picked up', () {
      expect(
        linksIn('http://a.test and https://b.test').map((l) => l.target),
        ['http://a.test', 'https://b.test'],
      );
    });

    test('a bare www host gets a scheme to open with', () {
      final link = linksIn('try www.example.com').single;

      expect(link.text, 'www.example.com');
      expect(link.target, 'https://www.example.com');
    });

    test('sentence punctuation is handed back to the sentence', () {
      for (final ending in ['.', ',', '!', '?', ';', ':']) {
        final link = linksIn('go to https://example.com$ending').single;
        expect(link.text, 'https://example.com', reason: 'ending "$ending"');
      }
    });

    test('a bracket the url opened itself is kept', () {
      final link = linksIn(
        'https://en.wikipedia.org/wiki/Dart_(language)',
      ).single;

      expect(link.text, 'https://en.wikipedia.org/wiki/Dart_(language)');
    });

    test('a bracket the sentence opened is not', () {
      final link = linksIn('(see https://example.com)').single;

      expect(link.text, 'https://example.com');
    });

    test('a bare domain without scheme or www stays plain text', () {
      // Otherwise every "3.5" and "etc.ok" in a sentence becomes a link.
      expect(linksIn('example.com is a site'), isEmpty);
    });
  });

  group('emails', () {
    test('an address becomes a mailto', () {
      final link = linksIn('write to ada@example.com please').single;

      expect(link.kind, MessageLinkKind.email);
      expect(link.target, 'mailto:ada@example.com');
    });

    test('an address is not read as a mention of its domain', () {
      final links = linksIn(
        'ada@example.com',
        members: {'example', 'ada'},
      );

      expect(links.single.kind, MessageLinkKind.email);
    });
  });

  group('mentions', () {
    test('a handle in the conversation becomes a link', () {
      final link = linksIn('thanks @ada!', members: {'ada'}).single;

      expect(link.kind, MessageLinkKind.mention);
      expect(link.text, '@ada');
      expect(link.target, 'ada');
    });

    test('matching ignores case, the handle keeps its own', () {
      final link = linksIn('hi @Ada', members: {'ada'}).single;

      expect(link.text, '@Ada');
      expect(link.target, 'Ada');
    });

    test('a handle nobody here has stays plain text', () {
      // A link to a profile that cannot be resolved is a link to nowhere.
      expect(linksIn('hi @nobody', members: {'ada'}), isEmpty);
    });

    test('with no resolver at all, nothing is a mention', () {
      expect(
        MessageLinkifier.parse('hi @ada').whereType<LinkSpan>(),
        isEmpty,
      );
    });

    test('an email address is not a mention', () {
      expect(
        linksIn('x@ada.com', members: {'ada'}).single.kind,
        MessageLinkKind.email,
      );
    });
  });

  group('phone numbers', () {
    test('an international number becomes a tel', () {
      final link = linksIn('call +1 (555) 010-9999 today').single;

      expect(link.kind, MessageLinkKind.phone);
      expect(link.target, 'tel:+15550109999');
    });

    test('the visible text keeps the formatting it was typed with', () {
      expect(linksIn('call +1 (555) 010-9999 today').single.text,
          '+1 (555) 010-9999');
    });

    test('a number without a plus is left alone', () {
      // Seq numbers, prices and version strings all look like digits.
      expect(linksIn('meet at 5550109999'), isEmpty);
    });

    test('too few digits to dial is not a number', () {
      expect(linksIn('scored +12345'), isEmpty);
    });

    test('too many digits to dial is not a number either', () {
      expect(linksIn('id +12345678901234567890'), isEmpty);
    });
  });

  group('several in one message', () {
    test('spans come back in the order they appear', () {
      final spans = parse(
        'hi @ada see https://example.com or ada@example.com or +15550109999',
        members: {'ada'},
      );

      expect(
        spans.whereType<LinkSpan>().map((l) => l.kind),
        [
          MessageLinkKind.mention,
          MessageLinkKind.url,
          MessageLinkKind.email,
          MessageLinkKind.phone,
        ],
      );
    });

    test('plain runs between links are merged, not split per match', () {
      final spans = parse('a https://x.test b https://y.test c');

      expect(spans.map((s) => s.runtimeType.toString()), [
        'PlainSpan',
        'LinkSpan',
        'PlainSpan',
        'LinkSpan',
        'PlainSpan',
      ]);
    });
  });
}
