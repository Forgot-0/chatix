import 'package:equatable/equatable.dart';

/// What a run of message text turned out to be.
enum MessageLinkKind { url, email, phone, mention }

/// A stretch of a message: either plain text or something worth tapping.
sealed class MessageSpan extends Equatable {
  const MessageSpan(this.text);

  /// Exactly the characters from the original content, never rewritten.
  final String text;

  @override
  List<Object?> get props => [text];
}

final class PlainSpan extends MessageSpan {
  const PlainSpan(super.text);
}

final class LinkSpan extends MessageSpan {
  const LinkSpan(super.text, {required this.kind, required this.target});

  final MessageLinkKind kind;

  /// What acting on the span means: a full URI for [MessageLinkKind.url],
  /// [MessageLinkKind.email] and [MessageLinkKind.phone]; the bare handle,
  /// without its `@`, for [MessageLinkKind.mention].
  final String target;

  @override
  List<Object?> get props => [text, kind, target];
}

/// Finds the tappable parts of a message.
///
/// Message content is stored and returned exactly as it was typed, with no
/// HTML escaping of any kind (api-docs §5.4). That makes rendering it through
/// anything that interprets markup — an HTML view, a Markdown renderer — a
/// way to hand an author control of the reader's screen. So the content is
/// only ever drawn as text, and this is the whole extent of the enrichment:
/// find spans, colour them, give them a tap target. Nothing is parsed into
/// anything that can execute.
abstract final class MessageLinkifier {
  /// One pass, ordered so the greedier shapes win.
  ///
  /// A URL is tried first because it can contain an `@` and a `.`; an email
  /// before a mention for the same reason. The mention's lookbehind keeps it
  /// from firing on the tail of an address that somehow got past the email
  /// branch.
  static final RegExp _pattern = RegExp(
    r'(?<url>(?:https?://|www\.)[^\s<>"' "'" r']+)'
    r'|(?<email>[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z]{2,})+)'
    r'|(?<mention>(?<![A-Za-z0-9_@.])@[A-Za-z0-9][A-Za-z0-9._-]{0,99})'
    r'|(?<phone>(?<![\d+])\+\d[\d  ()\-]{5,20}\d)',
    caseSensitive: false,
  );

  /// Characters a sentence puts after a link that are not part of it.
  static const String _trailing = '.,;:!?…"\'）)]}>';

  /// Splits [content] into spans covering it end to end.
  ///
  /// Adjacent plain runs are merged, so the result alternates between plain
  /// text and links. An empty or whitespace-only input yields a single plain
  /// span, which keeps callers from special-casing it.
  ///
  /// [isKnownMention] decides whether an `@handle` is worth offering as a
  /// tap. Usernames are permissive enough to contain spaces (api-docs §4.2),
  /// so there is no pattern that reliably ends one — resolving against people
  /// actually in the conversation is what makes a mention real. Handles that
  /// do not resolve stay plain text rather than becoming a link to nowhere.
  static List<MessageSpan> parse(
    String content, {
    bool Function(String handle)? isKnownMention,
  }) {
    if (content.isEmpty) return const [PlainSpan('')];

    final spans = <MessageSpan>[];
    var cursor = 0;

    void addPlain(String text) {
      if (text.isEmpty) return;
      final last = spans.isEmpty ? null : spans.last;
      if (last is PlainSpan) {
        spans[spans.length - 1] = PlainSpan(last.text + text);
      } else {
        spans.add(PlainSpan(text));
      }
    }

    for (final match in _pattern.allMatches(content)) {
      final span = _spanOf(match, isKnownMention: isKnownMention);
      if (span == null) continue;

      addPlain(content.substring(cursor, match.start));
      spans.add(span);
      // The span may be shorter than the match once trailing punctuation is
      // handed back to the sentence.
      cursor = match.start + span.text.length;
      addPlain(content.substring(cursor, match.end));
      cursor = match.end;
    }

    addPlain(content.substring(cursor));

    return spans.isEmpty ? const [PlainSpan('')] : spans;
  }

  static LinkSpan? _spanOf(
    RegExpMatch match, {
    required bool Function(String handle)? isKnownMention,
  }) {
    final url = match.namedGroup('url');
    if (url != null) {
      final text = _trimTrailing(url);
      if (text.isEmpty) return null;
      return LinkSpan(
        text,
        kind: MessageLinkKind.url,
        // A bare `www.` host is still a web address; anything else keeps the
        // scheme its author typed.
        target: text.toLowerCase().startsWith('www.') ? 'https://$text' : text,
      );
    }

    final email = match.namedGroup('email');
    if (email != null) {
      final text = _trimTrailing(email);
      if (!text.contains('@')) return null;
      return LinkSpan(
        text,
        kind: MessageLinkKind.email,
        target: 'mailto:$text',
      );
    }

    final mention = match.namedGroup('mention');
    if (mention != null) {
      final handle = _trimTrailing(mention).substring(1);
      if (handle.isEmpty) return null;
      if (isKnownMention == null || !isKnownMention(handle)) return null;
      return LinkSpan(
        '@$handle',
        kind: MessageLinkKind.mention,
        target: handle,
      );
    }

    final phone = match.namedGroup('phone');
    if (phone != null) {
      final text = _trimTrailing(phone).trimRight();
      final digits = text.replaceAll(RegExp(r'[^\d]'), '');
      // Short enough to be a price or a score rather than a number to dial.
      if (digits.length < 7 || digits.length > 15) return null;
      return LinkSpan(text, kind: MessageLinkKind.phone, target: 'tel:+$digits');
    }

    return null;
  }

  /// Gives back the punctuation that ended the sentence rather than the link.
  ///
  /// A closing bracket is kept when the link opened one itself, which is what
  /// keeps encyclopedia-style URLs intact.
  static String _trimTrailing(String raw) {
    var end = raw.length;
    while (end > 0) {
      final char = raw[end - 1];
      if (!_trailing.contains(char)) break;
      if (char == ')' && _isBalanced(raw.substring(0, end))) break;
      end--;
    }
    return raw.substring(0, end);
  }

  static bool _isBalanced(String value) {
    var depth = 0;
    for (final char in value.split('')) {
      if (char == '(') depth++;
      if (char == ')') depth--;
    }
    return depth == 0;
  }
}
