import 'package:flutter/widgets.dart';

/// Edits the composer makes to its own text from outside the keyboard — an
/// emoji from the panel, the panel's backspace, a mention picked from the
/// list. Pure, so they can be checked without a field.
///
/// Every edit works on what the field holds right now, selection included:
/// the caret is where the person put it, and replacing a selection is what a
/// keyboard does too.
abstract final class ComposerTextEdits {
  /// [insert] in place of the selection, caret after it.
  ///
  /// A field that never had focus has no valid selection; then the text goes
  /// at the end, which is where the eye already is.
  static TextEditingValue insert(TextEditingValue value, String insert) {
    final text = value.text;
    final selection = _selectionIn(value);

    return TextEditingValue(
      text: text.replaceRange(selection.start, selection.end, insert),
      selection: TextSelection.collapsed(
        offset: selection.start + insert.length,
      ),
    );
  }

  /// [replacement] in place of `start..end`, caret after it — what picking
  /// a mention does to the `@query` it was picked for.
  static TextEditingValue replaceRange(
    TextEditingValue value,
    int start,
    int end,
    String replacement,
  ) {
    final text = value.text;
    final from = start.clamp(0, text.length);
    final to = end.clamp(from, text.length);

    return TextEditingValue(
      text: text.replaceRange(from, to, replacement),
      selection: TextSelection.collapsed(offset: from + replacement.length),
    );
  }

  /// Deletes the selection, or the one character before the caret.
  ///
  /// One *character* as a reader counts them: a flag, a family, a thumbs-up
  /// with a skin tone are several code points each and go as one, the same
  /// as the keyboard's own backspace — never leaving half an emoji behind.
  static TextEditingValue backspace(TextEditingValue value) {
    final text = value.text;
    final selection = _selectionIn(value);

    if (!selection.isCollapsed) {
      return TextEditingValue(
        text: text.replaceRange(selection.start, selection.end, ''),
        selection: TextSelection.collapsed(offset: selection.start),
      );
    }

    final before = text.substring(0, selection.start);
    if (before.isEmpty) return value;

    final kept = before.characters.skipLast(1).string;
    return TextEditingValue(
      text: kept + text.substring(selection.start),
      selection: TextSelection.collapsed(offset: kept.length),
    );
  }

  static TextSelection _selectionIn(TextEditingValue value) {
    final length = value.text.length;
    final selection = value.selection;
    if (!selection.isValid) return TextSelection.collapsed(offset: length);

    final start = selection.start.clamp(0, length);
    final end = selection.end.clamp(0, length);
    return TextSelection(baseOffset: start, extentOffset: end);
  }
}
