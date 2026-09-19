import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/gen/l10n/app_localizations.dart';

/// The ARB files are the source of truth, and `flutter gen_l10n` will happily
/// generate a locale that is half English: a missing key silently falls back
/// to the template. This is the check that says so out loud.
void main() {
  final arbDir = Directory('lib/l10n/arb');

  Map<String, dynamic> readRaw(String locale) {
    final file = File('${arbDir.path}/intl_$locale.arb');
    expect(file.existsSync(), isTrue, reason: 'no ARB for $locale');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  Map<String, String> read(String locale) {
    final decoded = readRaw(locale);
    return {
      for (final entry in decoded.entries)
        if (!entry.key.startsWith('@')) entry.key: entry.value as String,
    };
  }

  /// The argument a plural is switched on, or null when there is no plural.
  String? pluralArgOf(String message) => RegExp(
    r'\{([A-Za-z_][A-Za-z0-9_]*),\s*plural,',
  ).firstMatch(message)?.group(1);

  late Map<String, String> template;

  /// What each message is actually allowed to interpolate, taken from the
  /// template's own `@key.placeholders` plus the argument any plural is
  /// switched on.
  ///
  /// Read rather than inferred, because `=1{Yesterday}` looks exactly like
  /// a `{name}` slot to a regular expression and is not one.
  late Map<String, Set<String>> templatePlaceholders;

  setUpAll(() {
    template = read('en');

    final raw = readRaw('en');
    templatePlaceholders = {
      for (final key in template.keys)
        key: <String>{
          ...?(raw['@$key'] as Map<String, dynamic>?)?['placeholders']
                  is Map<String, dynamic>
              ? ((raw['@$key'] as Map<String, dynamic>)['placeholders']
                        as Map<String, dynamic>)
                    .keys
              : null,
          ...?switch (pluralArgOf(template[key]!)) {
            final String arg => <String>{arg},
            null => null,
          },
        },
    };
  });

  test('the template is not empty, in case the path ever moves', () {
    expect(template.length, greaterThan(500));
  });

  test('every supported locale has an ARB file', () {
    for (final locale in AppLocalizations.supportedLocales) {
      expect(
        File('${arbDir.path}/intl_${locale.languageCode}.arb').existsSync(),
        isTrue,
        reason: '${locale.languageCode} is supported but has no ARB',
      );
    }
  });

  test('Russian is one of them', () {
    // Added in this pass, and the reason `preferred-supported-locales` in
    // l10n.yaml had to change as well — the list there is what decides the
    // order `supportedLocales` comes out in.
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode),
      contains('ru'),
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final code = locale.languageCode;

    group(code, () {
      test('translates every key in the template', () {
        final messages = read(code);
        final missing = template.keys
            .where((key) => !messages.containsKey(key))
            .toList();

        expect(
          missing,
          isEmpty,
          reason:
              '$code is missing ${missing.length} keys and would show '
              'English for them: ${missing.take(10).join(', ')}',
        );
      });

      test('carries no key the template does not have', () {
        final messages = read(code);
        final extra = messages.keys
            .where((key) => !template.containsKey(key))
            .toList();

        expect(extra, isEmpty, reason: '$code has orphaned keys: $extra');
      });

      test('keeps every placeholder the template declares', () {
        final messages = read(code);

        for (final entry in templatePlaceholders.entries) {
          final translated = messages[entry.key];
          if (translated == null) continue;

          for (final slot in entry.value) {
            expect(
              translated,
              contains('{$slot}'),
              reason:
                  '$code / ${entry.key} drops {$slot}, which leaves a hole '
                  'in the sentence at runtime rather than at build time',
            );
          }
        }
      });

      test('switches its plurals on the same argument', () {
        final messages = read(code);

        for (final entry in template.entries) {
          final translated = messages[entry.key];
          if (translated == null) continue;

          expect(
            pluralArgOf(translated),
            pluralArgOf(entry.value),
            reason: '$code / ${entry.key}',
          );
        }
      });

      test('has balanced braces everywhere', () {
        final messages = read(code);

        for (final entry in messages.entries) {
          final open = '{'.allMatches(entry.value).length;
          final close = '}'.allMatches(entry.value).length;
          expect(open, close, reason: '$code / ${entry.key}');
        }
      });

      if (code != 'en') {
        test('is actually translated, not a copy of the template', () {
          final messages = read(code);

          // Proper nouns, format patterns and a handful of loanwords are
          // legitimately identical, so this asks for a majority rather than
          // for every single line.
          final identical = template.entries
              .where((e) => messages[e.key] == e.value)
              .length;

          expect(
            identical / template.length,
            lessThan(0.2),
            reason:
                '$code repeats the English string for $identical of '
                '${template.length} keys',
          );
        });
      }
    });
  }

  // Russian needs `few` and `many`; a translation that only has `other`
  // reads as broken grammar for 2-4 and for 5+.
  group('Russian plural categories', () {
    test('counters carry the forms Russian actually inflects', () {
      final ru = read('ru');

      final plurals = ru.entries
          .where((e) => pluralArgOf(e.value) != null)
          .toList();

      expect(plurals.length, greaterThan(15));

      // The ones whose noun does not inflect (abbreviations like "мин",
      // "ч") legitimately need only `other`.
      const invariant = {'timeMinutesAgo', 'timeHoursAgo', 'bioCounter'};

      for (final entry in plurals) {
        if (invariant.contains(entry.key)) continue;

        for (final form in ['few', 'many']) {
          expect(
            entry.value,
            contains('$form{'),
            reason: 'ru / ${entry.key} has no "$form" form',
          );
        }
      }
    });

    test('no plural declares both =1 and one, which collide', () {
      // `Intl.pluralLogic` returns the `one` parameter for exactly 1, and
      // gen_l10n has only that one slot to put a value in — so a message
      // carrying both silently loses the first.
      final ru = read('ru');

      for (final entry in ru.entries) {
        if (pluralArgOf(entry.value) == null) continue;

        final hasExactOne = RegExp(r'(?<![\w=])=1\{').hasMatch(entry.value);
        final hasOne = RegExp(r'(?<![\w=])one\{').hasMatch(entry.value);

        expect(
          hasExactOne && hasOne,
          isFalse,
          reason: 'ru / ${entry.key} declares both =1 and one',
        );
      }
    });
  });
}
