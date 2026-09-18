import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/auth/presentation/screens/verify_email_screen.dart';

/// The "check your mail" screen submits whatever it finds in the clipboard,
/// and `POST /auth/verifications/email/verify/` allows three attempts an
/// hour (api-docs §3.6) — so what counts as a code matters more than usual.
void main() {
  group('extractVerificationToken', () {
    test('takes a bare code, whitespace and all', () {
      expect(extractVerificationToken('  abc123def  '), 'abc123def');
    });

    test('takes the token out of a confirmation link', () {
      expect(
        extractVerificationToken(
          'https://chatix.example/verify-email?token=abc123def&lang=en',
        ),
        'abc123def',
      );
    });

    test('falls back to the last path segment of a link', () {
      expect(
        extractVerificationToken('https://chatix.example/verify/abc123def'),
        'abc123def',
      );
    });

    test('refuses a link with nothing code-shaped in it', () {
      expect(
        extractVerificationToken('https://chatix.example/help'),
        isNull,
      );
    });

    test('refuses prose, so a copied sentence is not spent as an attempt', () {
      expect(extractVerificationToken('here is your code, enjoy'), isNull);
      expect(extractVerificationToken('короткий'), isNull);
    });

    test('refuses an empty or missing clipboard', () {
      expect(extractVerificationToken(null), isNull);
      expect(extractVerificationToken('   '), isNull);
    });

    test('refuses something too short or too long to be a code', () {
      expect(extractVerificationToken('ab12'), isNull);
      expect(extractVerificationToken('a' * 600), isNull);
    });

    test('accepts the characters a URL-safe token is made of', () {
      expect(
        extractVerificationToken('eyJhbGci.OiJIUzI1-NiJ9_abc='),
        'eyJhbGci.OiJIUzI1-NiJ9_abc=',
      );
    });
  });
}
