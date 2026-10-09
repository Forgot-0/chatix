import 'dart:io' show Cookie, HttpHeaders, SameSite;
import 'dart:typed_data' show Uint8List;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/network/interceptors/refresh_cookie_policy_interceptor.dart';
import 'package:chatix/core/network/refresh_cookie_policy.dart';
import 'package:chatix/core/network/secure_cookie_jar.dart';

/// Hands back one canned response, so the whole interceptor chain runs, and
/// keeps what each request carried.
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.setCookie, {this.status = 200});

  final String? setCookie;
  final int status;

  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      status == 200
          ? '{"access_token":"a.b.c"}'
          : '{"error":{"code":"NOT_AUTHENTICATED","message":"no","detail":null}}',
      status,
      headers: {
        HttpHeaders.contentTypeHeader: ['application/json'],
        if (setCookie != null) HttpHeaders.setCookieHeader: [setCookie!],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The refresh cookie is kept only with `HttpOnly`, `Secure` and `SameSite`,
/// and only ever sent over an encrypted connection.
void main() {
  const base = 'https://api.example.com/api/v1';
  final refreshUri = Uri.parse('$base/auth/refresh/');

  const compliant =
      'refresh_token=eyJhbGciOi.payload.sig; Path=/; HttpOnly; Secure; '
      'SameSite=Strict';

  late CookieJar jar;
  late _CannedAdapter adapter;

  setUp(() => jar = SecureCookieJar(CookieJar()));

  Dio buildDio({String? setCookie, int status = 200, String baseUrl = base}) {
    adapter = _CannedAdapter(setCookie, status: status);
    return Dio(BaseOptions(baseUrl: baseUrl))
      ..interceptors.addAll([
        const RefreshCookiePolicyInterceptor(),
        CookieManager(jar),
      ])
      ..httpClientAdapter = adapter;
  }

  Matcher refusedFor(Set<RefreshCookieAttribute> missing) => throwsA(
    isA<DioException>().having(
      (e) => e.error,
      'error',
      isA<InsecureRefreshCookieException>().having(
        (e) => e.missing,
        'missing',
        missing,
      ),
    ),
  );

  test(
    'a login with the documented cookie goes through and keeps it',
    () async {
      final response = await buildDio(
        setCookie: compliant,
      ).post<dynamic>('/auth/login/');

      expect(response.statusCode, 200);
      final saved = await jar.loadForRequest(refreshUri);
      expect(saved.single.name, 'refresh_token');
      expect(saved.single.httpOnly, isTrue);
      expect(saved.single.secure, isTrue);
      expect(saved.single.sameSite, SameSite.strict);
    },
  );

  group('a login whose cookie lacks an attribute is refused', () {
    for (final (header, missing) in [
      (
        'refresh_token=x; Path=/; Secure; SameSite=Strict',
        {RefreshCookieAttribute.httpOnly},
      ),
      (
        'refresh_token=x; Path=/; HttpOnly; SameSite=Strict',
        {RefreshCookieAttribute.secure},
      ),
      (
        'refresh_token=x; Path=/; HttpOnly; Secure',
        {RefreshCookieAttribute.sameSite},
      ),
      (
        'refresh_token=x; Path=/; HttpOnly; Secure; SameSite=None',
        {RefreshCookieAttribute.sameSite},
      ),
      // What the client used to repair and accept.
      (
        'refresh_token=x; Path=/; SameSite=none',
        RefreshCookieAttribute.values.toSet(),
      ),
    ]) {
      test(header, () async {
        await expectLater(
          buildDio(setCookie: header).post<dynamic>('/auth/login/'),
          refusedFor(missing),
        );
        expect(
          await jar.loadForRequest(refreshUri),
          isEmpty,
          reason: 'nothing of it may be kept',
        );
      });
    }
  });

  test('a refused cookie does not replace a good one already kept', () async {
    await buildDio(setCookie: compliant).post<dynamic>('/auth/login/');

    await expectLater(
      buildDio(
        setCookie: 'refresh_token=worse; Path=/; SameSite=none',
      ).post<dynamic>('/auth/refresh/'),
      throwsA(isA<DioException>()),
    );

    expect(
      (await jar.loadForRequest(refreshUri)).single.value,
      'eyJhbGciOi.payload.sig',
    );
  });

  test('other cookies on the same line are still kept', () async {
    await expectLater(
      buildDio(
        setCookie: 'theme=dark; Path=/,refresh_token=x; Path=/; SameSite=none',
      ).post<dynamic>('/auth/login/'),
      throwsA(isA<DioException>()),
    );

    final saved = await jar.loadForRequest(refreshUri);
    expect(saved.map((cookie) => cookie.name), ['theme']);
  });

  test('logout deleting the cookie is not held to the policy', () async {
    await buildDio(setCookie: compliant).post<dynamic>('/auth/login/');

    // What a framework's delete_cookie sends: none of the attributes.
    final response = await buildDio(
      setCookie: 'refresh_token=""; Max-Age=0; Path=/',
    ).post<dynamic>('/auth/logout/');

    expect(response.statusCode, 200);
    expect(await jar.loadForRequest(refreshUri), isEmpty);
  });

  test('an error response loses the cookie but keeps its own error', () async {
    await expectLater(
      buildDio(
        setCookie: 'refresh_token=x; Path=/',
        status: 401,
      ).post<dynamic>('/auth/refresh/'),
      throwsA(
        isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.badResponse)
            .having((e) => e.response?.statusCode, 'status', 401),
      ),
    );
    expect(await jar.loadForRequest(refreshUri), isEmpty);
  });

  group('sending it', () {
    test('goes out over https', () async {
      await buildDio(setCookie: compliant).post<dynamic>('/auth/login/');
      await buildDio().post<dynamic>('/auth/refresh/');

      expect(
        adapter.requests.single.headers[HttpHeaders.cookieHeader],
        contains('refresh_token='),
      );
    });

    test('never over plain http, Secure meaning what it says', () async {
      // Stored for the host, then asked for over http — which the stock jar
      // would happily answer.
      await jar.saveFromResponse(refreshUri, [
        Cookie('refresh_token', 'abc')
          ..path = '/'
          ..httpOnly = true
          ..secure = true
          ..sameSite = SameSite.strict,
      ]);

      await buildDio(
        baseUrl: 'http://api.example.com/api/v1',
      ).post<dynamic>('/auth/refresh/');

      expect(adapter.requests.single.headers[HttpHeaders.cookieHeader], isNull);
    });

    test('a cookie kept before the policy is not sent', () async {
      // Saved straight into the inner jar, the way an old install has it on
      // disk: patched up to parse, never HttpOnly, SameSite=None.
      final inner = CookieJar();
      jar = SecureCookieJar(inner);
      await inner.saveFromResponse(refreshUri, [
        Cookie('refresh_token', 'old')
          ..path = '/'
          ..secure = true
          ..sameSite = SameSite.none,
      ]);

      await buildDio().post<dynamic>('/auth/refresh/');

      expect(adapter.requests.single.headers[HttpHeaders.cookieHeader], isNull);
    });
  });

  test('ApiClient reports it as an insecure session, not as offline', () async {
    final client = ApiClient(
      buildDio(setCookie: 'refresh_token=x; Path=/; SameSite=none'),
    );

    final result = await client.post('/auth/login/');

    expect(result.getLeft().toNullable(), isA<InsecureSessionCookieFailure>());
  });
}
