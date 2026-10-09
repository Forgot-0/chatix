import 'package:cookie_jar/cookie_jar.dart';

import 'package:chatix/core/network/refresh_cookie_policy.dart';

/// The cookie jar with the two guarantees the stock one does not keep.
///
/// **`Secure` means encrypted transport.** `cookie_jar` 4.0.9 checks it as
/// `secure && scheme == 'https' || !expired`, which by precedence sends any
/// unexpired cookie over plain `http` too — `Secure` included. Here a secure
/// cookie only goes out over `https` or `wss`.
///
/// **The refresh cookie meets [RefreshCookiePolicy], or it does not exist.**
/// One that breaks the policy is not saved, and one saved before the policy
/// — when the client still patched cookies up to keep them — is not sent.
/// That session cannot be renewed, so the reader signs in once more and gets
/// a cookie that holds.
class SecureCookieJar implements CookieJar {
  SecureCookieJar(this._delegate);

  final CookieJar _delegate;

  @override
  bool get ignoreExpires => _delegate.ignoreExpires;

  @override
  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) =>
      _delegate.saveFromResponse(uri, [
        for (final cookie in cookies)
          if (RefreshCookiePolicy.missingFromCookie(cookie).isEmpty) cookie,
      ]);

  @override
  Future<List<Cookie>> loadForRequest(Uri uri) async {
    final encrypted = uri.scheme == 'https' || uri.scheme == 'wss';
    final cookies = await _delegate.loadForRequest(uri);

    return [
      for (final cookie in cookies)
        if ((encrypted || !cookie.secure) &&
            RefreshCookiePolicy.missingFromCookie(cookie).isEmpty)
          cookie,
    ];
  }

  @override
  Future<void> delete(Uri uri, [bool withDomainSharedCookie = false]) =>
      _delegate.delete(uri, withDomainSharedCookie);

  @override
  Future<void> deleteAll() => _delegate.deleteAll();
}
