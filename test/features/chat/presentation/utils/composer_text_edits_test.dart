import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/presentation/utils/composer_text_edits.dart';

/// What the emoji panel's taps and its backspace do to the text — the
/// keyboard's own rules, without the keyboard.
void main() {
  TextEditingValue at(String text, int caret) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret),
  );

  group('insert', () {
    test('goes in at the caret, and the caret follows it', () {
      final next = ComposerTextEdits.insert(at('Hi there', 2), ' 👋');

      expect(next.text, 'Hi 👋 there');
      expect(next.selection, TextSelection.collapsed(offset: 2 + ' 👋'.length));
    });

    test('replaces a selection, as typing would', () {
      const value = TextEditingValue(
        text: 'I am sad',
        selection: TextSelection(baseOffset: 5, extentOffset: 8),
      );

      final next = ComposerTextEdits.insert(value, '😢');

      expect(next.text, 'I am 😢');
      expect(next.selection.baseOffset, next.text.length);
    });

    test('a field that never had a caret gets it at the end', () {
      const value = TextEditingValue(text: 'Done');

      final next = ComposerTextEdits.insert(value, '✅');

      expect(next.text, 'Done✅');
      expect(next.selection.baseOffset, 'Done✅'.length);
    });

    test('a stale caret past the end is pulled back in', () {
      final next = ComposerTextEdits.insert(at('ab', 10), 'c');

      expect(next.text, 'abc');
    });
  });

  group('backspace', () {
    test('deletes the character before the caret', () {
      final next = ComposerTextEdits.backspace(at('abc', 2));

      expect(next.text, 'ac');
      expect(next.selection, const TextSelection.collapsed(offset: 1));
    });

    test('takes an emoji off whole, however many code points it is', () {
      for (final emoji in ['👍🏽', '🇺🇦', '👨‍👩‍👧‍👦', '❤️‍🔥', '😀']) {
        final text = 'ok $emoji';
        final next = ComposerTextEdits.backspace(at(text, text.length));

        expect(next.text, 'ok ', reason: emoji);
        expect(next.selection, const TextSelection.collapsed(offset: 3));
      }
    });

    test('deletes a selection rather than the character before it', () {
      const value = TextEditingValue(
        text: 'keep this',
        selection: TextSelection(baseOffset: 4, extentOffset: 9),
      );

      final next = ComposerTextEdits.backspace(value);

      expect(next.text, 'keep');
      expect(next.selection, const TextSelection.collapsed(offset: 4));
    });

    test('at the very start there is nothing to take', () {
      final value = at('text', 0);

      expect(ComposerTextEdits.backspace(value), value);
    });

    test('an empty field stays empty', () {
      final value = at('', 0);

      expect(ComposerTextEdits.backspace(value).text, isEmpty);
    });
  });
}
