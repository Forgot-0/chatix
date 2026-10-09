import 'dart:io' show Cookie, SameSite;

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/network/refresh_cookie_policy.dart';

/// What the refresh cookie has to carry: `HttpOnly`, `Secure` and a
/// `SameSite` that actually restricts something (api-docs §0.5, §9.2).
void main() {
  const value = 'refresh_token=eyJhbGciOi.payload.sig; Path=/';

  Set<RefreshCookieAttribute> missing(String setCookie) =>
      RefreshCookiePolicy.missingFrom(setCookie, now: DateTime.utc(2026, 10));

  group('a Set-Cookie header', () {
    test('what the server documents is accepted', () {
      expect(missing('$value; HttpOnly; Secure; SameSite=Strict'), isEmpty);
    });

    test('SameSite=Lax restricts cross-site use too, and is accepted', () {
      expect(missing('$value; HttpOnly; Secure; SameSite=Lax'), isEmpty);
    });

    test('attributes are read whatever their casing and spacing', () {
      expect(missing('$value;httponly;  SECURE ; samesite=strict'), isEmpty);
    });

    test('each attribute is required on its own', () {
      expect(missing('$value; Secure; SameSite=Strict'), {
        RefreshCookieAttribute.httpOnly,
      });
      expect(missing('$value; HttpOnly; SameSite=Strict'), {
        RefreshCookieAttribute.secure,
      });
      expect(missing('$value; HttpOnly; Secure'), {
        RefreshCookieAttribute.sameSite,
      });
    });

    test('SameSite=None counts as no SameSite at all', () {
      expect(missing('$value; HttpOnly; Secure; SameSite=None'), {
        RefreshCookieAttribute.sameSite,
      });
    });

    test(
      'the cookie the client used to patch up is refused on every count',
      () {
        expect(missing('$value; SameSite=none'), {
          RefreshCookieAttribute.httpOnly,
          RefreshCookieAttribute.secure,
          RefreshCookieAttribute.sameSite,
        });
      },
    );

    test('a value that reads "Secure" is not mistaken for the attribute', () {
      expect(missing('refresh_token=Secure; HttpOnly; SameSite=Strict'), {
        RefreshCookieAttribute.secure,
      });
    });

    test('other cookies are none of its business', () {
      expect(missing('theme=dark; Path=/'), isEmpty);
      expect(missing('refresh_token_hint=1; Path=/'), isEmpty);
    });

    group('a cookie that only deletes the refresh token is let through', () {
      test('Max-Age=0, as logout sends it', () {
        expect(missing('refresh_token=""; Max-Age=0; Path=/'), isEmpty);
      });

      test('an empty value', () {
        expect(missing('refresh_token=; Path=/'), isEmpty);
      });

      test('an Expires date already past', () {
        expect(
          missing(
            'refresh_token=abc; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/',
          ),
          isEmpty,
        );
      });

      test('but not one that only expires in the future', () {
        expect(
          missing(
            'refresh_token=abc; Expires=Fri, 01 Jan 2100 00:00:00 GMT; Path=/',
          ),
          hasLength(3),
        );
      });
    });
  });

  group('a cookie already parsed', () {
    Cookie cookie({
      String name = RefreshCookiePolicy.cookieName,
      String value = 'abc',
      bool httpOnly = true,
      bool secure = true,
      SameSite? sameSite = SameSite.strict,
    }) => Cookie(name, value)
      ..httpOnly = httpOnly
      ..secure = secure
      ..sameSite = sameSite;

    test('a compliant one is accepted', () {
      expect(RefreshCookiePolicy.missingFromCookie(cookie()), isEmpty);
    });

    test('one stored before the policy is refused', () {
      expect(
        RefreshCookiePolicy.missingFromCookie(
          cookie(httpOnly: false, sameSite: SameSite.none),
        ),
        {RefreshCookieAttribute.httpOnly, RefreshCookieAttribute.sameSite},
      );
      expect(RefreshCookiePolicy.missingFromCookie(cookie(secure: false)), {
        RefreshCookieAttribute.secure,
      });
      expect(RefreshCookiePolicy.missingFromCookie(cookie(sameSite: null)), {
        RefreshCookieAttribute.sameSite,
      });
    });

    test('a deletion is let through', () {
      expect(
        RefreshCookiePolicy.missingFromCookie(
          cookie(httpOnly: false, secure: false)..maxAge = 0,
        ),
        isEmpty,
      );
    });

    test('other cookies are none of its business', () {
      expect(
        RefreshCookiePolicy.missingFromCookie(
          cookie(name: 'theme', httpOnly: false, secure: false),
        ),
        isEmpty,
      );
    });
  });

  group('splitSetCookieHeader', () {
    test('splits several cookies sent on one line', () {
      final parts = RefreshCookiePolicy.splitSetCookieHeader(
        'a=1; Path=/; SameSite=Strict,b=2; Path=/',
      ).toList();

      expect(parts, hasLength(2));
      expect(parts.first, contains('a=1'));
      expect(parts.last, contains('b=2'));
    });

    test('keeps the comma inside an expires date', () {
      final parts = RefreshCookiePolicy.splitSetCookieHeader(
        'a=1; expires=Sun, 19 Feb 3000 01:43:15 GMT; SameSite=Strict',
      ).toList();

      expect(parts, hasLength(1));
    });
  });
}
