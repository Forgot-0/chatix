import 'package:flutter/material.dart';

/// Text cut in the middle rather than at the end, for names whose end is
/// the part that tells them apart.
///
/// A file called "Маршрут_поездки_по_Кавказу_март_2026.pdf" cut at the end
/// loses ".pdf" and the date — exactly what distinguishes it from last
/// year's. Cut in the middle it reads "Маршрут_поездки_по…2026.pdf": the
/// start says what it is, the end says which one, and the extension stays
/// in sight.
class MiddleEllipsisText extends StatelessWidget {
  const MiddleEllipsisText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.keepTail,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;

  /// How many characters at the end are never cut. Defaults to
  /// [defaultTail]: the extension and a few before it.
  final int? keepTail;

  /// The extension, its dot and four characters before it — "2026.pdf" —
  /// or six characters of a name with no extension.
  static int defaultTail(String text) {
    final length = text.characters.length;
    final dot = text.lastIndexOf('.');
    final extension = dot <= 0 ? 0 : text.substring(dot + 1).characters.length;
    final keep = extension > 0 && extension <= 5 ? extension + 1 + 4 : 6;
    return keep > length ~/ 2 ? length ~/ 2 : keep;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // What `Text` itself would resolve, so the fit measured here is the
        // fit that gets drawn.
        var effective = DefaultTextStyle.of(context).style.merge(style);
        if (MediaQuery.boldTextOf(context)) {
          effective = effective.merge(
            const TextStyle(fontWeight: FontWeight.bold),
          );
        }

        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: maxLines,
        );

        bool fits(String candidate) {
          painter
            ..text = TextSpan(text: candidate, style: effective)
            ..layout(maxWidth: constraints.maxWidth);
          return !painter.didExceedMaxLines;
        }

        final shown = constraints.maxWidth.isFinite
            ? middleEllipsis(
                text,
                fits: fits,
                keepTail: keepTail ?? defaultTail(text),
              )
            : text;
        painter.dispose();

        return Text(
          shown,
          style: style,
          maxLines: maxLines,
          // Only ever reached when even "…" and the tail do not fit.
          overflow: TextOverflow.ellipsis,
          semanticsLabel: text,
        );
      },
    );
  }
}

/// [text] with as much of its start as [fits] allows, an ellipsis, and its
/// last [keepTail] characters — or [text] itself when it fits whole.
///
/// Counted in grapheme clusters, so an emoji or an accented letter in a
/// filename is never split in half.
String middleEllipsis(
  String text, {
  required bool Function(String candidate) fits,
  required int keepTail,
  String ellipsis = '…',
}) {
  if (fits(text)) return text;

  final characters = text.characters.toList();
  final tailLength = keepTail.clamp(0, characters.length);
  final tail = characters.sublist(characters.length - tailLength).join();

  String candidate(int head) => '${characters.take(head).join()}$ellipsis$tail';

  // The longest start that still fits. More text never takes fewer lines,
  // so the answer is the edge between what fits and what does not.
  var low = 0;
  var high = characters.length - tailLength;
  if (!fits(candidate(low))) return candidate(low);

  while (low < high) {
    final middle = (low + high + 1) ~/ 2;
    if (fits(candidate(middle))) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }

  return candidate(low);
}
