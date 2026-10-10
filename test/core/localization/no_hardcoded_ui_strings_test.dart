import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Words a reader sees come from the ARB files, never from a literal.
///
/// `arb_completeness_test` proves every key is translated; it cannot see a
/// sentence that never became a key. Those used to slip in one at a time —
/// a validator's `errorText`, a field's default `labelText`, a hint under a
/// switch — and each one was English on a Russian screen. This reads the
/// source for the places text goes on screen and fails on any literal that
/// holds a word.
void main() {
  test('nothing in lib/ puts a literal word on screen', () {
    final offenders = <String>[];

    for (final file in _scannedFiles()) {
      final path = file.path.replaceAll(r'\', '/');
      for (final hit in findHardcodedUiStrings(file.readAsStringSync())) {
        offenders.add('$path:${hit.line}  ${hit.text}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Move these into lib/l10n/arb (intl_en.arb, intl_ru.arb and the '
          'other locales) and read them through AppLocalizations:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the scan actually reaches the presentation layer', () {
    // A moved directory would make the test above pass by reading nothing.
    final scanned = _scannedFiles()
        .map((file) => file.path.replaceAll(r'\', '/'))
        .toList();

    expect(scanned.length, greaterThan(200));
    expect(
      scanned,
      contains(
        endsWith('features/chat/presentation/screens/chat_detail_screen.dart'),
      ),
    );
    expect(
      scanned,
      contains(
        endsWith('features/auth/presentation/utils/auth_field_validators.dart'),
      ),
    );
  });

  group('the scanner', () {
    List<String> scan(String source) =>
        findHardcodedUiStrings(source).map((hit) => hit.text).toList();

    test('finds a literal in Text(), const or not, on any line', () {
      expect(scan("const Text('Hello there')"), ['Hello there']);
      expect(scan('Text("Hello")'), ['Hello']);
      expect(scan("Text(\n  'Spread over '\n  'two lines',\n)"), [
        'Spread over ',
        'two lines',
      ]);
      expect(scan("SelectableText('Copy me')"), ['Copy me']);
    });

    test('finds one in each field decoration argument', () {
      expect(scan("labelText: 'Name',"), ['Name']);
      expect(scan("hintText: 'Type here')"), ['Type here']);
      expect(scan("helperText: 'Up to \${max} people',"), [
        'Up to \${max} people',
      ]);
      expect(scan("errorText: 'Required')"), ['Required']);
    });

    test('looks into both arms of a condition', () {
      expect(scan("labelText: isDirect ? 'Who?' : l10n.addPeople,"), ['Who?']);
      expect(scan("helperText: a ? l10n.x : 'Pick one',"), ['Pick one']);
    });

    test('finds a default given to a label parameter', () {
      expect(scan("this.labelText = 'Search by name',"), ['Search by name']);
    });

    test('finds Russian as readily as English', () {
      expect(scan("Text('Привет')"), ['Привет']);
    });

    test('lets through what is not a word', () {
      expect(scan('Text(l10n.title)'), isEmpty);
      expect(scan("Text('\$count')"), isEmpty);
      expect(scan("Text('@\${profile.username}')"), isEmpty);
      expect(scan("Text('\${a} · \${b}')"), isEmpty);
      expect(scan("Text('—')"), isEmpty);
      expect(scan("Text('0:00')"), isEmpty);
      expect(scan('labelText: widget.label ?? l10n.search,'), isEmpty);
    });

    test('skips a key handed to a call or an index', () {
      expect(scan("Text(context.tr('language'))"), isEmpty);
      expect(scan("errorText: _serverErrorFor('username'),"), isEmpty);
      expect(scan("errorText: errors['email'],"), isEmpty);
      expect(scan("Text(map<String>('key'))"), isEmpty);
      // A bracket that only groups is still the argument's own value.
      expect(scan("Text(isDirect ? ('Grouped') : l10n.x)"), ['Grouped']);
      expect(scan("Text(name ?? 'Nobody')"), ['Nobody']);
    });

    test('stops at the end of the argument', () {
      // The key is not text; only the first argument of Text is.
      expect(scan("Text(l10n.title, key: const ValueKey('title'))"), isEmpty);
      expect(scan("labelText: l10n.name, semanticCounterText: 'x x'"), isEmpty);
    });

    test('ignores comments, and text that only mentions Text(', () {
      expect(scan("// Text('Not code')\nText(l10n.real)"), isEmpty);
      expect(scan("/* labelText: 'Old' */ labelText: l10n.name,"), isEmpty);
      expect(scan("final s = \"Text('quoted')\";"), isEmpty);
      expect(scan('RichText(text: span)'), isEmpty);
    });

    test('reports the line the literal starts on', () {
      final hits = findHardcodedUiStrings("a;\nb;\nText('Third')");
      expect(hits.single.line, 3);
    });
  });
}

/// Every Dart file that can draw text, minus what is not the app's: the
/// generated localizations, and the debug-only design system catalogue,
/// whose labels are token names (`primary`, `x4`, `fast`) rather than prose.
/// It is routed only under `kDebugMode` (app_router.dart), so no release
/// build can reach it.
Iterable<File> _scannedFiles() sync* {
  const skipped = ['lib/gen/', 'lib/features/ui_showcase/'];

  final files =
      Directory('lib').listSync(recursive: true).whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart')) continue;
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;
    if (skipped.any(path.startsWith)) continue;
    yield file;
  }
}

class HardcodedString {
  const HardcodedString(this.line, this.text);

  final int line;
  final String text;

  @override
  String toString() => '$line: $text';
}

/// Places a string goes on screen: the first argument of a text widget, a
/// field decoration's label, hint, helper and error, and the default value a
/// widget gives one of those.
final RegExp _anchor = RegExp(
  r'(?<![\w.])(?:SelectableText|Text)\(\s*'
  r'|\b(?:labelText|hintText|helperText|errorText)\s*:\s*'
  r'|\bthis\.(?:labelText|hintText|helperText|errorText)\s*=\s*',
);

final RegExp _word = RegExp(r'\p{L}{2,}', unicode: true);
final RegExp _interpolation = RegExp(r'\$\{[^}]*\}|\$[A-Za-z_]\w*');

/// Literals in [source] that put at least one word on screen.
///
/// Interpolations are taken out before looking for a word, so `'$count'` or
/// `'@${user.name}'` pass: the words in them come from somewhere else.
List<HardcodedString> findHardcodedUiStrings(String source) {
  final code = _blankComments(source);
  final hits = <HardcodedString>[];

  // Anchors are looked for with string contents blanked as well: a string
  // that happens to say "Text(" is not a text widget.
  for (final anchor in _anchor.allMatches(_blankStrings(code))) {
    final end = _argumentEnd(code, anchor.end);
    for (final literal in _literalsBetween(code, anchor.end, end)) {
      final shown = literal.text.replaceAll(_interpolation, '');
      if (!_word.hasMatch(shown)) continue;

      final line = '\n'.allMatches(code.substring(0, literal.start)).length + 1;
      hits.add(HardcodedString(line, literal.text));
    }
  }
  return hits;
}

typedef _Literal = ({int start, String text});

/// [source] with every comment replaced by spaces, newlines kept, so that
/// offsets and line numbers still match the file.
String _blankComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final string = _readString(source, i);
    if (string != null) {
      out.write(source.substring(i, string.end));
      i = string.end;
      continue;
    }
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      final stop = end == -1 ? source.length : end;
      out.write(' ' * (stop - i));
      i = stop;
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      final stop = end == -1 ? source.length : end + 2;
      out.write(source.substring(i, stop).replaceAll(RegExp(r'[^\n]'), ' '));
      i = stop;
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}

/// [code] with every string literal filled in, newlines kept.
String _blankStrings(String code) {
  final out = StringBuffer();
  var i = 0;
  while (i < code.length) {
    final string = _readString(code, i);
    if (string == null) {
      out.write(code[i]);
      i++;
      continue;
    }
    out.write(
      // Not spaces: the anchors' `\s*` would read a blanked string as the
      // gap before the argument and step over it.
      code.substring(i, string.end).replaceAll(RegExp(r'[^\n]'), '#'),
    );
    i = string.end;
  }
  return out.toString();
}

/// Where the argument starting at [start] ends: the first `,` `)` `]` `}` or
/// `;` that is not inside brackets or a string.
int _argumentEnd(String code, int start) {
  var depth = 0;
  var i = start;
  while (i < code.length) {
    final string = _readString(code, i);
    if (string != null) {
      i = string.end;
      continue;
    }
    final char = code[i];
    if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      if (depth == 0) return i;
      depth--;
    } else if ((char == ',' || char == ';') && depth == 0) {
      return i;
    }
    i++;
  }
  return code.length;
}

/// The literals that are the argument's own value — in either arm of a
/// condition, in a concatenation, in parentheses — but not the ones handed
/// to a call or an index inside it: `context.tr('language')` and
/// `_serverErrorFor('username')` pass a key, the text comes back from
/// somewhere else.
Iterable<_Literal> _literalsBetween(String code, int start, int end) sync* {
  final opaque = <bool>[];
  var i = start;
  while (i < end) {
    final string = _readString(code, i);
    if (string != null) {
      if (!opaque.contains(true)) yield (start: i, text: string.text);
      i = string.end;
      continue;
    }

    final char = code[i];
    if (char == '(' || char == '[') {
      opaque.add(_isCallOrIndex(code, i));
    } else if (char == '{') {
      opaque.add(false);
    } else if ((char == ')' || char == ']' || char == '}') &&
        opaque.isNotEmpty) {
      opaque.removeLast();
    }
    i++;
  }
}

/// Whether the bracket at [i] opens a call's arguments or an index rather
/// than a group or a list: what comes right before it is a name, a type's
/// closing `>`, or the end of another call.
bool _isCallOrIndex(String code, int i) {
  var j = i - 1;
  while (j >= 0 && (code[j] == ' ' || code[j] == '\n' || code[j] == '\r')) {
    j--;
  }
  if (j < 0) return false;
  return RegExp(r'[\w$)\]>]').hasMatch(code[j]);
}

/// The string literal starting at [i], if one does: its content and the
/// offset just past its closing quote. Knows raw strings, triple quotes,
/// escapes and `${...}` interpolations with strings of their own inside.
({int end, String text})? _readString(String code, int i) {
  var at = i;
  var raw = false;
  if (code[at] == 'r' &&
      at + 1 < code.length &&
      (code[at + 1] == "'" || code[at + 1] == '"') &&
      (at == 0 || !RegExp(r'\w').hasMatch(code[at - 1]))) {
    raw = true;
    at++;
  }

  final char = code[at];
  if (char != "'" && char != '"') return null;

  final triple = code.startsWith(char * 3, at);
  final quote = triple ? char * 3 : char;
  final contentStart = at + quote.length;

  var j = contentStart;
  while (j < code.length) {
    if (code.startsWith(quote, j)) {
      return (end: j + quote.length, text: code.substring(contentStart, j));
    }
    if (!triple && code[j] == '\n') break;
    if (!raw && code[j] == r'\') {
      j += 2;
      continue;
    }
    if (!raw && code.startsWith(r'${', j)) {
      var depth = 1;
      j += 2;
      while (j < code.length && depth > 0) {
        final inner = _readString(code, j);
        if (inner != null) {
          j = inner.end;
          continue;
        }
        if (code[j] == '{') depth++;
        if (code[j] == '}') depth--;
        j++;
      }
      continue;
    }
    j++;
  }

  // An unterminated quote is an apostrophe in prose, not a string.
  return null;
}
