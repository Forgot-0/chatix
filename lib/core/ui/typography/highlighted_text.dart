import 'package:flutter/material.dart';

import 'package:chatix/core/utils/text_match.dart';

/// Text with the part someone searched for picked out of it.
///
/// The highlight is a weight and a tint rather than a block of colour: a
/// result list is read top to bottom, and a row of yellow blocks is harder to
/// read than the text it is trying to help with.
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.matchStart,
    this.matchLength,
  });

  final String text;

  /// What to pick out. Ignored when [matchStart] says where the match is.
  final String query;

  final TextStyle? style;

  /// Defaults to the same style in the primary colour, bolded.
  final TextStyle? highlightStyle;

  final int? maxLines;

  final TextOverflow overflow;

  /// Where the one match sits, for callers that already worked it out —
  /// a snippet knows its own match and should not have to find it again.
  final int? matchStart;

  final int? matchLength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.bodyMedium;
    final accent =
        highlightStyle ??
        (base ?? const TextStyle()).copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        );

    final ranges = _ranges();

    if (ranges.isEmpty) {
      return Text(text, style: base, maxLines: maxLines, overflow: overflow);
    }

    final spans = <TextSpan>[];
    var cursor = 0;

    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: accent,
        ),
      );
      cursor = range.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  List<TextMatchRange> _ranges() {
    final start = matchStart;
    final length = matchLength;

    if (start != null && length != null && length > 0) {
      if (start < 0 || start + length > text.length) {
        return const <TextMatchRange>[];
      }
      return [TextMatchRange(start, start + length)];
    }

    return findMatches(text, query);
  }
}
