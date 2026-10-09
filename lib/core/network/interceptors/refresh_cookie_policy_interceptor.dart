import 'dart:io' show HttpHeaders;

import 'package:dio/dio.dart';

import 'package:chatix/core/network/refresh_cookie_policy.dart';

/// Refuses a refresh cookie that arrives without `HttpOnly`, `Secure` and
/// `SameSite` ([RefreshCookiePolicy]).
///
/// Such a cookie is taken off the response before the cookie manager can
/// store it, and the response itself fails with
/// [InsecureRefreshCookieException]: a login that "succeeded" with a session
/// this client will not keep would only end five minutes later, as a
/// session that expired for no reason anyone could see. Failing at the door
/// says what is wrong.
///
/// Error responses lose the cookie the same way but keep their own error —
/// the cookie manager saves cookies off those too.
///
/// Must sit **before** `CookieManager`: dio runs response interceptors in
/// the order they were added.
class RefreshCookiePolicyInterceptor extends Interceptor {
  const RefreshCookiePolicyInterceptor();

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final missing = _strip(response);
    if (missing == null) {
      handler.next(response);
      return;
    }

    handler.reject(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: InsecureRefreshCookieException(missing),
        message:
            '${RefreshCookiePolicy.cookieName} refused: '
            'no ${missing.map((a) => a.wireName).join(', ')}',
      ),
      true,
    );
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null) _strip(response);
    handler.next(err);
  }

  /// Takes every refresh cookie that breaks the policy out of [response]'s
  /// headers, and says what the first of them lacked — null when there was
  /// none.
  static Set<RefreshCookieAttribute>? _strip(Response<dynamic> response) {
    final headers = response.headers;
    final values = headers[HttpHeaders.setCookieHeader];
    if (values == null || values.isEmpty) return null;

    Set<RefreshCookieAttribute>? missing;
    final kept = <String>[];

    for (final cookie in values.expand(
      RefreshCookiePolicy.splitSetCookieHeader,
    )) {
      final lacks = RefreshCookiePolicy.missingFrom(cookie);
      if (lacks.isEmpty) {
        kept.add(cookie);
      } else {
        missing ??= lacks;
      }
    }

    if (missing == null) return null;

    if (kept.isEmpty) {
      headers.removeAll(HttpHeaders.setCookieHeader);
    } else {
      headers.set(HttpHeaders.setCookieHeader, kept);
    }
    return missing;
  }
}
