import 'package:chatix/core/utils/text_match.dart';

/// A search query cut up the way the server cuts it.
///
/// `GET /chats/messages/search/` runs Postgres full-text with the `simple`
/// configuration: the query is split on everything that is not a letter or a
/// digit, the terms are lowercased, the last one matches by prefix and the
/// rest exactly, and at most ten of them count (api-docs §5.4.1).
///
/// The client needs the same rules for one thing the server does not do:
/// deciding which part of a message to show and what to pick out of it. A
/// result for `бюджет догов` does not contain that string anywhere, so
/// looking for it whole would highlight nothing.
class MessageSearchTerms {
  const MessageSearchTerms(this.terms);

  factory MessageSearchTerms.of(String query) {
    final parts = query
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((part) => part.isNotEmpty)
        .take(maxTerms)
        .toList();

    return MessageSearchTerms(parts);
  }

  /// Terms past this one are ignored by the server.
  static const int maxTerms = 10;

  final List<String> terms;

  bool get isEmpty => terms.isEmpty;

  /// Every place any term shows up in [text], in order, without overlaps.
  ///
  /// A term is highlighted wherever it appears inside a word, which is what
  /// makes the prefix match visible: searching `догов` picks the first five
  /// letters out of `договор`.
  List<TextMatchRange> highlightsIn(String text) {
    if (text.isEmpty || isEmpty) return const <TextMatchRange>[];

    final found = <TextMatchRange>[];
    for (final term in terms) {
      found.addAll(findMatches(text, term));
    }
    if (found.isEmpty) return const <TextMatchRange>[];

    found.sort((a, b) => a.start.compareTo(b.start));

    final merged = <TextMatchRange>[found.first];
    for (final range in found.skip(1)) {
      final last = merged.last;
      if (range.start <= last.end) {
        if (range.end > last.end) {
          merged[merged.length - 1] = TextMatchRange(last.start, range.end);
        }
        continue;
      }
      merged.add(range);
    }

    return merged;
  }

  /// Where the shown part of a message should start from: the first term
  /// that appears in it, or -1 when none does.
  ///
  /// A message can match on a term the snippet has no room for, and one that
  /// matches on nothing visible at all is still a real result — the index is
  /// built from the whole content.
  int firstMatchIn(String text) {
    var earliest = -1;

    for (final term in terms) {
      final index = firstMatch(text, term);
      if (index < 0) continue;
      if (earliest < 0 || index < earliest) earliest = index;
    }

    return earliest;
  }
}
