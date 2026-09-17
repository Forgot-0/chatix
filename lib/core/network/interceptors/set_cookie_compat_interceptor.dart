import 'dart:io' show HttpHeaders;

import 'package:dio/dio.dart';

/// Makes a `Set-Cookie` header Dart is willing to parse.
///
/// `POST /auth/login/` and `POST /auth/refresh/` set the refresh cookie as
/// `SameSite=none` with no `Secure` attribute. RFC-6265bis says that pair is
/// invalid, and Dart enforces it: `Cookie.fromSetCookieValue` throws
/// `HttpException("Cookie with 'SameSite=None' must also have the 'Secure'
/// attribute.")`. `CookieManager` turns that into a rejected response, so a
/// perfectly good `200` carrying an access token arrives at the app as a
/// `DioException` — which the error mapper reads as "no internet connection".
///
/// So the header is repaired before the cookie manager ever sees it. Over
/// HTTPS the missing attribute is added, which is what the server meant.
/// Anywhere else `Secure` would make the cookie unsendable, so the offending
/// `SameSite` attribute is dropped instead and the cookie falls back to the
/// default — either way it is stored, which is what keeps the five-minute
/// access token renewable.
///
/// Must sit **before** `CookieManager` in the chain: dio runs response
/// interceptors in the order they were added.
///
/// This is a workaround, not a fix. The server should send `Secure` alongside
/// `SameSite=None`; browsers reject the pair for the same reason Dart does.
class SetCookieCompatInterceptor extends Interceptor {
  const SetCookieCompatInterceptor();

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _repair(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // `CookieManager` saves cookies off failed responses too, and would throw
    // there for the same reason.
    final response = err.response;
    if (response != null) _repair(response);
    handler.next(err);
  }

  static void _repair(Response<dynamic> response) {
    final headers = response.headers;
    final setCookies = headers[HttpHeaders.setCookieHeader];
    if (setCookies == null || setCookies.isEmpty) return;

    final isSecureTransport =
        response.requestOptions.uri.resolveUri(response.realUri).scheme ==
        'https';

    final repaired = setCookies
        .expand(splitSetCookieHeader)
        .map((cookie) => repairSetCookie(cookie, isSecureTransport: isSecureTransport))
        .toList(growable: false);

    headers.set(HttpHeaders.setCookieHeader, repaired);
  }

  /// Splits a header that carries several cookies in one line.
  ///
  /// The same rule `dio_cookie_manager` uses: a comma only separates cookies
  /// when what follows is an attribute-free `name=`, so the comma inside
  /// `expires=Sun, 19 Feb 3000 …` stays put.
  static Iterable<String> splitSetCookieHeader(String value) =>
      value.split(_separator).where((cookie) => cookie.trim().isNotEmpty);

  static final RegExp _separator = RegExp('(?<=)(,)(?=[^;]+?=)');

  /// One `Set-Cookie` value, made parseable.
  static String repairSetCookie(
    String setCookie, {
    required bool isSecureTransport,
  }) {
    final parts = setCookie.split(';');
    if (parts.length < 2) return setCookie;

    var hasSameSiteNone = false;
    var hasSecure = false;

    // From index 1: the first part is `name=value`, and a cookie may be named
    // "secure" or "samesite" without that meaning anything.
    for (final part in parts.skip(1)) {
      final attribute = part.trim().toLowerCase();
      if (attribute == 'secure') hasSecure = true;
      if (attribute == 'samesite=none') hasSameSiteNone = true;
    }

    if (!hasSameSiteNone || hasSecure) return setCookie;

    if (isSecureTransport) return '$setCookie; Secure';

    return [
      parts.first,
      ...parts.skip(1).where(
        (part) => part.trim().toLowerCase() != 'samesite=none',
      ),
    ].join(';');
  }
}
