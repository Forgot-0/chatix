import 'dart:io' show HttpHeaders;
import 'dart:typed_data' show Uint8List;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/network/interceptors/set_cookie_compat_interceptor.dart';

/// Hands back one canned response, so the whole interceptor chain runs.
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.setCookie);

  final String setCookie;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"access_token":"a.b.c"}',
      200,
      headers: {
        HttpHeaders.contentTypeHeader: ['application/json'],
        HttpHeaders.setCookieHeader: [setCookie],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The server sets the refresh cookie as `SameSite=none` with no `Secure`.
/// Dart refuses to parse that pair, `CookieManager` turns the refusal into a
/// rejected response, and a `200` carrying the access token reaches the app as
/// a `DioException` that reads as "no internet connection".
void main() {
  const refreshCookie =
      'refresh_token=eyJhbGciOi.payload.sig; Path=/; SameSite=none';

  Dio buildDio(CookieJar jar, {bool withCompat = true, String? setCookie}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v1'));
    if (withCompat) {
      dio.interceptors.add(const SetCookieCompatInterceptor());
    }
    dio.interceptors.add(CookieManager(jar));
    dio.httpClientAdapter = _CannedAdapter(setCookie ?? refreshCookie);
    return dio;
  }

  test('without the repair, a successful login is rejected', () async {
    final dio = buildDio(CookieJar(), withCompat: false);

    await expectLater(
      dio.post<dynamic>('/auth/login/'),
      throwsA(
        isA<DioException>().having(
          (e) => e.error.toString(),
          'error',
          contains('Secure'),
        ),
      ),
    );
  });

  test('with the repair, the login response comes through', () async {
    final dio = buildDio(CookieJar());

    final response = await dio.post<dynamic>('/auth/login/');

    expect(response.statusCode, 200);
    expect(response.data, {'access_token': 'a.b.c'});
  });

  test('the refresh cookie is actually stored, not just tolerated', () async {
    final jar = CookieJar();
    await buildDio(jar).post<dynamic>('/auth/login/');

    final saved = await jar.loadForRequest(
      Uri.parse('https://api.example.com/api/v1/auth/refresh/'),
    );

    expect(saved, hasLength(1));
    expect(saved.single.name, 'refresh_token');
    expect(saved.single.value, 'eyJhbGciOi.payload.sig');
    // Renewing the five-minute access token depends on this cookie existing.
    expect(saved.single.secure, isTrue);
  });

  group('repairSetCookie', () {
    test('adds Secure over https', () {
      expect(
        SetCookieCompatInterceptor.repairSetCookie(
          refreshCookie,
          isSecureTransport: true,
        ),
        '$refreshCookie; Secure',
      );
    });

    test('drops SameSite=None over http, where Secure would strand it', () {
      final repaired = SetCookieCompatInterceptor.repairSetCookie(
        refreshCookie,
        isSecureTransport: false,
      );

      expect(repaired.toLowerCase(), isNot(contains('samesite')));
      expect(repaired.toLowerCase(), isNot(contains('secure')));
      expect(repaired, contains('refresh_token=eyJhbGciOi.payload.sig'));
    });

    test('leaves a cookie that already says Secure alone', () {
      const valid = 'a=b; Path=/; SameSite=None; Secure';

      expect(
        SetCookieCompatInterceptor.repairSetCookie(
          valid,
          isSecureTransport: true,
        ),
        valid,
      );
    });

    test('leaves SameSite=Lax and Strict alone', () {
      for (final cookie in const [
        'a=b; Path=/; SameSite=Lax',
        'a=b; Path=/; SameSite=Strict',
      ]) {
        expect(
          SetCookieCompatInterceptor.repairSetCookie(
            cookie,
            isSecureTransport: true,
          ),
          cookie,
        );
      }
    });

    test('reads the attribute whatever its casing', () {
      expect(
        SetCookieCompatInterceptor.repairSetCookie(
          'a=b; samesite=NONE',
          isSecureTransport: true,
        ),
        'a=b; samesite=NONE; Secure',
      );
    });

    test('a cookie named "secure" is not mistaken for the attribute', () {
      expect(
        SetCookieCompatInterceptor.repairSetCookie(
          'secure=1; SameSite=None',
          isSecureTransport: true,
        ),
        'secure=1; SameSite=None; Secure',
      );
    });

    test('a bare name=value pair is left as it is', () {
      expect(
        SetCookieCompatInterceptor.repairSetCookie(
          'a=b',
          isSecureTransport: true,
        ),
        'a=b',
      );
    });
  });

  group('splitSetCookieHeader', () {
    test('splits several cookies sent on one line', () {
      final parts = SetCookieCompatInterceptor.splitSetCookieHeader(
        'a=1; Path=/; SameSite=none,b=2; Path=/',
      ).toList();

      expect(parts, hasLength(2));
      expect(parts.first, contains('a=1'));
      expect(parts.last, contains('b=2'));
    });

    test('keeps the comma inside an expires date', () {
      final parts = SetCookieCompatInterceptor.splitSetCookieHeader(
        'a=1; expires=Sun, 19 Feb 3000 01:43:15 GMT; SameSite=none',
      ).toList();

      expect(parts, hasLength(1));
    });
  });

  test('two cookies on one line are both repaired and both stored', () async {
    final jar = CookieJar();
    await buildDio(
      jar,
      setCookie: 'a=1; Path=/; SameSite=none,b=2; Path=/; SameSite=none',
    ).post<dynamic>('/auth/login/');

    final saved = await jar.loadForRequest(
      Uri.parse('https://api.example.com/api/v1/auth/refresh/'),
    );

    expect(saved.map((c) => c.name).toSet(), {'a', 'b'});
  });
}
