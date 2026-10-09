import 'dart:io' show Cookie, HttpDate, SameSite;

/// An attribute the refresh cookie may not arrive without.
enum RefreshCookieAttribute {
  /// Keeps the cookie out of reach of anything but the HTTP stack.
  httpOnly('HttpOnly'),

  /// Keeps it off unencrypted connections.
  secure('Secure'),

  /// Keeps it off cross-site requests: `Strict` or `Lax`. `None` is the
  /// opposite of the guarantee and counts as missing.
  sameSite('SameSite');

  const RefreshCookieAttribute(this.wireName);

  final String wireName;
}

/// What the refresh cookie must carry before this client keeps or sends it.
///
/// The server sets `refresh_token` as `HttpOnly; Secure; SameSite=Strict`
/// (api-docs §0.5, §3, §9.2). This client used to repair a cookie that came
/// without them, so a backend serving plain `http` could still be signed in
/// to. That is over: the refresh token is a sixty-day credential, and a copy
/// of it that travels unencrypted or cross-site is a copy somebody else can
/// spend. A refresh cookie without all three is refused outright.
///
/// Only the refresh cookie is held to this. A cookie that merely deletes it —
/// what logout sends, often with none of the attributes — can only take a
/// credential away, and is let through.
abstract final class RefreshCookiePolicy {
  /// The cookie `POST /auth/login/` and `POST /auth/refresh/` set.
  static const String cookieName = 'refresh_token';

  /// The attributes a raw `Set-Cookie` value lacks, or nothing when it is
  /// compliant, is some other cookie, or deletes the refresh cookie.
  ///
  /// Read off the header text rather than through [Cookie.fromSetCookieValue]:
  /// whether Dart's parser accepts `SameSite=None` without `Secure` depends
  /// on the SDK, and the answer here must not.
  static Set<RefreshCookieAttribute> missingFrom(
    String setCookie, {
    DateTime? now,
  }) {
    final parts = setCookie.split(';');
    final pair = parts.first;
    final equals = pair.indexOf('=');
    if (equals < 0) return const {};

    final name = pair.substring(0, equals).trim();
    if (name != cookieName) return const {};

    final value = _unquote(pair.substring(equals + 1).trim());

    var httpOnly = false;
    var secure = false;
    var sameSiteHolds = false;
    int? maxAge;
    DateTime? expires;

    // From index 1: the first part is `name=value`, so a value that happens
    // to read "Secure" is never mistaken for the attribute.
    for (final part in parts.skip(1)) {
      final attribute = part.trim();
      final cut = attribute.indexOf('=');
      final key = (cut < 0 ? attribute : attribute.substring(0, cut))
          .trim()
          .toLowerCase();
      final argument = cut < 0 ? '' : attribute.substring(cut + 1).trim();

      switch (key) {
        case 'httponly':
          httpOnly = true;
        case 'secure':
          secure = true;
        case 'samesite':
          final mode = argument.toLowerCase();
          sameSiteHolds = mode == 'strict' || mode == 'lax';
        case 'max-age':
          maxAge = int.tryParse(argument);
        case 'expires':
          expires = _parseDate(argument);
      }
    }

    if (_deletes(value: value, maxAge: maxAge, expires: expires, now: now)) {
      return const {};
    }

    return {
      if (!httpOnly) RefreshCookieAttribute.httpOnly,
      if (!secure) RefreshCookieAttribute.secure,
      if (!sameSiteHolds) RefreshCookieAttribute.sameSite,
    };
  }

  /// The same question about a cookie already parsed — one stored before
  /// these rules, or handed over by the cookie manager.
  static Set<RefreshCookieAttribute> missingFromCookie(
    Cookie cookie, {
    DateTime? now,
  }) {
    if (cookie.name != cookieName) return const {};

    if (_deletes(
      value: _unquote(cookie.value),
      maxAge: cookie.maxAge,
      expires: cookie.expires,
      now: now,
    )) {
      return const {};
    }

    final sameSite = cookie.sameSite;
    return {
      if (!cookie.httpOnly) RefreshCookieAttribute.httpOnly,
      if (!cookie.secure) RefreshCookieAttribute.secure,
      if (sameSite != SameSite.strict && sameSite != SameSite.lax)
        RefreshCookieAttribute.sameSite,
    };
  }

  /// Splits a header that carries several cookies on one line.
  ///
  /// The rule `dio_cookie_manager` uses: a comma only separates cookies when
  /// what follows is an attribute-free `name=`, so the comma inside
  /// `expires=Sun, 19 Feb 3000 …` stays put.
  static Iterable<String> splitSetCookieHeader(String value) =>
      value.split(_separator).where((cookie) => cookie.trim().isNotEmpty);

  static final RegExp _separator = RegExp('(?<=)(,)(?=[^;]+?=)');

  static bool _deletes({
    required String value,
    required int? maxAge,
    required DateTime? expires,
    DateTime? now,
  }) {
    if (value.isEmpty) return true;
    if (maxAge != null && maxAge <= 0) return true;
    return expires != null && !expires.isAfter(now ?? DateTime.now());
  }

  static String _unquote(String value) =>
      value.length >= 2 && value.startsWith('"') && value.endsWith('"')
      ? value.substring(1, value.length - 1)
      : value;

  static DateTime? _parseDate(String value) {
    try {
      return HttpDate.parse(value);
    } on Exception {
      // An unreadable date is not a deletion; the cookie is judged on its
      // attributes like any other.
      return null;
    }
  }
}

/// A login or refresh answered with a refresh cookie that does not meet
/// [RefreshCookiePolicy]. The cookie was not kept.
class InsecureRefreshCookieException implements Exception {
  const InsecureRefreshCookieException(this.missing);

  final Set<RefreshCookieAttribute> missing;

  @override
  String toString() =>
      'InsecureRefreshCookieException: ${RefreshCookiePolicy.cookieName} '
      'arrived without ${missing.map((a) => a.wireName).join(', ')}';
}
