import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/auth/presentation/utils/password_strength.dart';

/// The meter is only useful if it agrees with `POST /users/register/`, which
/// refuses a password at the schema level and says nothing about which rule
/// it missed (api-docs §3.2). Every "weak" here is a password the server
/// would bounce; every "acceptable" is one it would take.
void main() {
  group('estimatePasswordStrength', () {
    test('an empty field is not a verdict', () {
      expect(estimatePasswordStrength(''), PasswordStrength.empty);
      expect(PasswordStrength.empty.isAcceptable, isFalse);
    });

    test('anything the server would refuse is weak, however long', () {
      // Missing a digit, missing a symbol, missing an uppercase letter,
      // missing a lowercase one, and too short — one rule each.
      const refused = [
        'Passwordpass!',
        'Password12345',
        'password123!',
        'PASSWORD123!',
        'Pa1!aaa',
      ];

      for (final password in refused) {
        expect(
          estimatePasswordStrength(password),
          PasswordStrength.weak,
          reason: '$password is missing one of the required classes',
        );
      }
    });

    test('a 40-character passphrase with no digit is still weak', () {
      const passphrase = 'correct horse battery staple correct hors';
      expect(passphrase.length, greaterThan(16));
      expect(estimatePasswordStrength(passphrase), PasswordStrength.weak);
    });

    test('meeting every rule at the minimum length passes, barely', () {
      final strength = estimatePasswordStrength('Pa1!abcd');
      expect(strength, PasswordStrength.fair);
      expect(strength.isAcceptable, isTrue);
    });

    test('length above the minimum is what separates the passing grades', () {
      expect(estimatePasswordStrength('Pa1!abcdefgh'), PasswordStrength.good);
      expect(
        estimatePasswordStrength('Pa1!abcdefghijkl'),
        PasswordStrength.strong,
      );
    });

    test('past the 128-character ceiling is refused again', () {
      final tooLong = 'Pa1!${'a' * 130}';
      expect(estimatePasswordStrength(tooLong), PasswordStrength.weak);
    });

    test('the meter grows with the grade', () {
      expect(PasswordStrength.empty.fraction, 0);
      expect(
        PasswordStrength.weak.fraction,
        lessThan(PasswordStrength.fair.fraction),
      );
      expect(
        PasswordStrength.good.fraction,
        lessThan(PasswordStrength.strong.fraction),
      );
      expect(PasswordStrength.strong.fraction, 1);
    });
  });

  // The checklist under a new password ticks these off one by one; each has
  // to agree with the server on its own, not only all five together.
  group('PasswordRule', () {
    test('length counts 8 to 128 characters, both ends included', () {
      expect(PasswordRule.length.isMetBy('a' * 7), isFalse);
      expect(PasswordRule.length.isMetBy('a' * 8), isTrue);
      expect(PasswordRule.length.isMetBy('a' * 128), isTrue);
      expect(PasswordRule.length.isMetBy('a' * 129), isFalse);
    });

    test('each character class is told apart from the others', () {
      expect(PasswordRule.uppercase.isMetBy('abc'), isFalse);
      expect(PasswordRule.uppercase.isMetBy('aBc'), isTrue);
      expect(PasswordRule.lowercase.isMetBy('ABC'), isFalse);
      expect(PasswordRule.lowercase.isMetBy('AbC'), isTrue);
      expect(PasswordRule.digit.isMetBy('abc'), isFalse);
      expect(PasswordRule.digit.isMetBy('ab3'), isTrue);
    });

    test("only the server's own symbols count as special", () {
      for (final symbol in r'!@#$%^&*(),.?":{}|<>'.split('')) {
        expect(
          PasswordRule.special.isMetBy('a$symbol'),
          isTrue,
          reason: symbol,
        );
      }
      // Common, and not in the set: the checklist must not tick them.
      for (final symbol in ['-', '_', '+', '=', '/', '~', ' ']) {
        expect(
          PasswordRule.special.isMetBy('a$symbol'),
          isFalse,
          reason: symbol,
        );
      }
    });

    test(
      'a non-Latin letter is neither upper- nor lowercase to the server',
      () {
        expect(PasswordRule.uppercase.isMetBy('Пароль'), isFalse);
        expect(PasswordRule.lowercase.isMetBy('пароль'), isFalse);
      },
    );

    test('meeting every rule is exactly what the meter calls acceptable', () {
      const samples = ['', 'short', 'Chatix2026', 'Chatix2026!', 'Pa1!a'];
      for (final password in samples) {
        final allMet = PasswordRule.values.every((r) => r.isMetBy(password));
        expect(
          estimatePasswordStrength(password).isAcceptable,
          allMet,
          reason: password,
        );
      }
    });
  });
}
