import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/auth/access_token_refresher.dart';
import 'package:chatix/core/auth/session_events.dart';
import 'package:chatix/core/constants/app_constants.dart';

import '../../helpers/fakes/fake_secure_storage_service.dart';

/// Answers `POST /auth/refresh/` however the test tells it to, and counts.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.onRequest);

  FutureOr<ResponseBody> Function(RequestOptions) onRequest;

  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return onRequest(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, Object?> body, int status) => ResponseBody.fromString(
  json.encode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody _envelope(String code, int status) => _json({
  'error': {'code': code, 'message': code, 'detail': null},
  'status': status,
}, status);

/// One renewal path for the whole client. The socket cannot retry a rejected
/// handshake the way a request can, so it has to be able to ask for a token
/// it knows is good — and neither half may ask twice at once, because
/// `POST /auth/refresh/` spends a cookie (api-docs §0).
void main() {
  late FakeSecureStorageService storage;
  late _StubAdapter adapter;
  late Dio side;
  late SessionExpiredSignal signal;
  late List<SessionExpiredReason> expiries;

  /// A token that expires [inSeconds] from now, shaped like a real one.
  String token(String id, {required int inSeconds}) {
    String segment(Object value) =>
        base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');

    final exp =
        DateTime.now().add(Duration(seconds: inSeconds)).millisecondsSinceEpoch ~/
        1000;
    return '${segment({'alg': 'HS256'})}.${segment({'exp': exp, 'jti': id})}.sig';
  }

  AccessTokenRefresher wire({
    required FutureOr<ResponseBody> Function(RequestOptions) onRefresh,
    String? stored,
  }) {
    storage = FakeSecureStorageService(
      initialValues: stored == null
          ? null
          : {AppConstants.accessTokenKey: stored},
    );

    adapter = _StubAdapter(onRefresh);
    side = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v1'))
      ..httpClientAdapter = adapter;

    signal = SessionExpiredSignal();
    expiries = [];
    signal.stream.listen(expiries.add);

    return AccessTokenRefresher(
      sideChannel: side,
      secureStorage: storage,
      sessionExpiredSignal: signal,
    );
  }

  ResponseBody fresh(RequestOptions _) =>
      _json({'access_token': token('fresh', inSeconds: 300)}, 200);

  test('a token with life left is handed back untouched', () async {
    final live = token('live', inSeconds: 240);
    final refresher = wire(onRefresh: fresh, stored: live);

    expect(await refresher.token(), live);
    expect(adapter.requests, isEmpty, reason: 'nothing to renew');
  });

  test('an expired one is renewed before it is handed back', () async {
    final refresher = wire(
      onRefresh: fresh,
      stored: token('stale', inSeconds: -10),
    );

    final renewed = await refresher.token();

    expect(adapter.requests.single.path, '/auth/refresh/');
    expect(renewed, isNot(token('stale', inSeconds: -10)));
    expect(await storage.read(key: AppConstants.accessTokenKey), renewed);
  });

  test('one about to expire is renewed too', () async {
    // It would die between the handshake leaving and arriving.
    final refresher = wire(
      onRefresh: fresh,
      stored: token('nearly', inSeconds: 5),
    );

    await refresher.token();
    expect(adapter.requests, hasLength(1));
  });

  test('a forced renewal ignores how healthy the token looks', () async {
    // What a 1008 close means: the gateway has already refused this token,
    // whatever its `exp` claims.
    final live = token('live', inSeconds: 240);
    final refresher = wire(onRefresh: fresh, stored: live);

    final renewed = await refresher.token(forceRefresh: true);

    expect(adapter.requests, hasLength(1));
    expect(renewed, isNot(live));
  });

  test('two callers arriving together make one request', () async {
    final refresher = wire(
      onRefresh: (options) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return fresh(options);
      },
      stored: token('stale', inSeconds: -10),
    );

    final results = await Future.wait([refresher.token(), refresher.token()]);

    expect(adapter.requests, hasLength(1));
    expect(results.first, results.last);
  });

  test('a caller that missed the renewal is handed its result', () async {
    final refresher = wire(onRefresh: fresh, stored: null);

    final first = await refresher.token(forceRefresh: true);
    // Arrives after the first finished, with the token it started with.
    final second = await refresher.refresh(knownStale: null);

    expect(adapter.requests, hasLength(1));
    expect(second, first);
  });

  group('when the session is really over', () {
    test('a dead refresh session ends it', () async {
      final refresher = wire(
        onRefresh: (_) => _envelope('NOT_FOUND_OR_INACTIVE_SESSION', 404),
        stored: token('stale', inSeconds: -10),
      );

      expect(await refresher.token(), isNull);
      await Future<void>.delayed(Duration.zero);

      expect(expiries, [SessionExpiredReason.refreshFailed]);
      expect(await storage.read(key: AppConstants.accessTokenKey), isNull);
    });

    test('a 200 with no token in it ends it too', () async {
      final refresher = wire(
        onRefresh: (_) => _json(const {}, 200),
        stored: token('stale', inSeconds: -10),
      );

      expect(await refresher.token(), isNull);
      await Future<void>.delayed(Duration.zero);

      expect(expiries, [SessionExpiredReason.refreshFailed]);
    });
  });

  test('a refresh that could not be made does not sign anybody out', () async {
    // No network is not the session ending, and treating it as one would
    // sign people out for going through a tunnel.
    final refresher = wire(
      onRefresh: (options) =>
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'no route to host',
          ),
      stored: token('stale', inSeconds: -10),
    );

    expect(await refresher.token(), isNull);
    await Future<void>.delayed(Duration.zero);

    expect(expiries, isEmpty);
    expect(
      await storage.read(key: AppConstants.accessTokenKey),
      isNotNull,
      reason: 'the token is kept: it may well still work',
    );
  });
}
