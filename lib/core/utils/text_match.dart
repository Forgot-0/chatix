/// Where a search needle sits inside a piece of text.
class TextMatchRange {
  const TextMatchRange(this.start, this.end);

  final int start;
  final int end;

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is TextMatchRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TextMatchRange($start, $end)';
}

/// Every place [needle] occurs in [haystack], ignoring case.
///
/// Case folding is `toLowerCase` on both sides, which is what a reader
/// expects from a search box and what the matching in the rest of the app
/// already does. Matches never overlap: the scan restarts after each one.
List<TextMatchRange> findMatches(
  String haystack,
  String needle, {
  int limit = 50,
}) {
  if (haystack.isEmpty || needle.isEmpty || limit <= 0) {
    return const <TextMatchRange>[];
  }

  final hay = haystack.toLowerCase();
  final target = needle.toLowerCase();

  final ranges = <TextMatchRange>[];
  var from = 0;

  while (ranges.length < limit) {
    final index = hay.indexOf(target, from);
    if (index < 0) break;

    ranges.add(TextMatchRange(index, index + target.length));
    from = index + target.length;
  }

  return ranges;
}

/// The first place [needle] occurs, or -1.
int firstMatch(String haystack, String needle) {
  if (haystack.isEmpty || needle.isEmpty) return -1;
  return haystack.toLowerCase().indexOf(needle.toLowerCase());
}

bool containsIgnoreCase(String haystack, String needle) =>
    firstMatch(haystack, needle) >= 0;

/// A slice of text cut around a match, with the match's place inside it.
class TextSnippet {
  const TextSnippet({
    required this.text,
    required this.matchStart,
    required this.matchLength,
  });

  final String text;

  /// Offset of the match inside [text], not inside the original.
  final int matchStart;

  final int matchLength;

  bool get hasMatch => matchStart >= 0 && matchLength > 0;
}

/// Cuts [text] down to a window around the first match of [needle].
///
/// A message can be four thousand characters long (api-docs §5.4) and a
/// result row has one or two lines, so showing the head of the message would
/// often show nothing of why it matched. This keeps [lead] characters before
/// the match and fills up to [maxLength], marking either cut with an
/// ellipsis. Whitespace is collapsed first, because a result row cannot show
/// the line breaks anyway.
TextSnippet snippetAround(
  String text,
  String needle, {
  int maxLength = 120,
  int lead = 24,
}) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  final index = firstMatch(flat, needle);
  if (index < 0) {
    return TextSnippet(
      text: flat.length <= maxLength ? flat : '${flat.substring(0, maxLength)}…',
      matchStart: -1,
      matchLength: 0,
    );
  }

  if (flat.length <= maxLength) {
    return TextSnippet(
      text: flat,
      matchStart: index,
      matchLength: needle.length,
    );
  }

  var start = index - lead;
  if (start < 0) start = 0;

  var end = start + maxLength;
  if (end > flat.length) {
    end = flat.length;
    start = end - maxLength;
    if (start < 0) start = 0;
  }

  final head = start > 0 ? '…' : '';
  final tail = end < flat.length ? '…' : '';

  return TextSnippet(
    text: '$head${flat.substring(start, end)}$tail',
    matchStart: index - start + head.length,
    matchLength: needle.length,
  );
}
