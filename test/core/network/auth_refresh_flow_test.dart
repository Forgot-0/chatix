import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/auth/session_events.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/network/interceptors/auth_interceptor.dart';

import '../../helpers/fakes/fake_secure_storage_service.dart';

/// End-to-end coverage of the api-docs §2.3/§3.4 refresh flow through a real
/// [Dio] pair, with a stub adapter standing in for the network.
///
/// Two protocol details drive every test here, and getting either wrong makes
/// the app retry forever with a dead token:
///
/// 1. **`EXPIRED_TOKEN` is HTTP 400, not 401** (§2.3). 401 means "no
///    `Authorization` header at all"; the expiry that happens every 5 minutes
///    is a 400.
/// 2. **Error bodies arrive without a `Content-Type` header**, so Dio hands
///    them to the interceptor as raw JSON *strings* rather than decoded maps
///    (`Transformer.isJsonMimeType(null) == false`). The fixtures below
///    reproduce that faithfully — [_json] deliberately sets no content type —
///    because a fixture that sent one would pass while production failed.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;

  /// Every request that reached this adapter, in order.
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A JSON body **without** a `Content-Type` header — how this gateway serves
/// its error responses, and the reason Dio hands them over as raw strings.
ResponseBody _bareJson(Object body, int statusCode) =>
    ResponseBody.fromString(jsonEncode(body), statusCode);

/// A JSON body **with** `Content-Type: application/json` — how the same
/// gateway serves successful responses, which is why the asymmetry went
/// unnoticed for so long.
ResponseBody _json(Object body, int statusCode) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

/// The §2.1 envelope.
Map<String, dynamic> _envelope(String code, {String message = 'error'}) => {
  'error': {'code': code, 'message': message, 'detail': <String, dynamic>{}},
  'status': 400,
  'request_id': 'req-1',
  'timestamp': 1788557769.449433,
};

void main() {
  const protectedPath = '/notifications/unread_count/';

  late FakeSecureStorageService storage;
  late Dio main;
  late Dio side;
  late _StubAdapter mainAdapter;
  late _StubAdapter sideAdapter;
  late SessionExpiredSignal signal;
  late List<SessionExpiredReason> expiries;

  /// Wires a main client carrying [AuthInterceptor] and the auth-free side
  /// channel it refreshes and replays through.
  void wire({
    required FutureOr<ResponseBody> Function(RequestOptions) onMain,
    required FutureOr<ResponseBody> Function(RequestOptions) onSide,
    String? storedToken = 'expired-token',
  }) {
    storage = FakeSecureStorageService(
      initialValues: storedToken == null
          ? null
          : {AppConstants.accessTokenKey: storedToken},
    );

    mainAdapter = _StubAdapter(onMain);
    sideAdapter = _StubAdapter(onSide);

    main = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v1'))
      ..httpClientAdapter = mainAdapter;
    side = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v1'))
      ..httpClientAdapter = sideAdapter;

    signal = SessionExpiredSignal();
    expiries = [];
    signal.stream.listen(expiries.add);

    main.interceptors.add(
      AuthInterceptor(
        sideChannel: side,
        secureStorage: storage,
        sessionExpiredSignal: signal,
      ),
    );
  }

  group('400 EXPIRED_TOKEN triggers a refresh (§2.3)', () {
    test('refreshes, replays, and returns the replayed response', () async {
      wire(
        // The exact shape from production: 400, envelope body, no content type.
        onMain: (_) => _bareJson(_envelope('EXPIRED_TOKEN'), 400),
        onSide: (options) => options.path.endsWith('/auth/refresh/')
            ? _json({'access_token': 'fresh-token'}, 200)
            : _json({'unread_count': 0}, 200),
      );

      final response = await main.get<dynamic>(protectedPath);

      // The refresh actually went out — the symptom in the bug report was that
      // it never did.
      expect(
        sideAdapter.requests.map((r) => r.path),
        contains('/auth/refresh/'),
      );

      // The caller sees the replay's success, not the 400.
      expect(response.statusCode, 200);

      // The new token is persisted for every subsequent request...
      expect(
        await storage.read(key: AppConstants.accessTokenKey),
        'fresh-token',
      );

      // ...and the replay itself already carried it.
      final replay = sideAdapter.requests.last;
      expect(replay.headers['Authorization'], 'Bearer fresh-token');

      // A recoverable expiry must not sign the user out.
      expect(expiries, isEmpty);
    });

    test('a Map body works too — the header is not always absent', () async {
      // A gateway change that starts sending `Content-Type` must not regress
      // the flow, so both decoded forms are pinned.
      wire(
        onMain: (_) => _json(_envelope('EXPIRED_TOKEN'), 400),
        onSide: (options) => options.path.endsWith('/auth/refresh/')
            ? _json({'access_token': 'fresh-token'}, 200)
            : _json({'unread_count': 0}, 200),
      );

      final response = await main.get<dynamic>(protectedPath);

      expect(response.statusCode, 200);
      expect(
        await storage.read(key: AppConstants.accessTokenKey),
        'fresh-token',
      );
    });

    test('a burst of expired requests refreshes only once', () async {
      // Refreshing per request would be wasteful, and worse: a backend that
      // rotates the refresh cookie invalidates it on first use, so refreshes
      // 2..N come back dead and log out a healthy session.
      wire(
        onMain: (_) => _bareJson(_envelope('EXPIRED_TOKEN'), 400),
        onSide: (options) => options.path.endsWith('/auth/refresh/')
            ? _json({'access_token': 'fresh-token'}, 200)
            : _json({'unread_count': 0}, 200),
      );

      await Future.wait([
        main.get<dynamic>(protectedPath),
        main.get<dynamic>('/chats/'),
        main.get<dynamic>('/profiles/1/'),
      ]);

      final refreshes = sideAdapter.requests
          .where((r) => r.path.endsWith('/auth/refresh/'))
          .length;
      expect(refreshes, 1);
      expect(expiries, isEmpty);
    });
  });

  group('the refresh response is parsed defensively too', () {
    test('a refresh 200 without a Content-Type still yields the token', () {
      // Same header asymmetry, one layer deeper: if this body were cast to a
      // Map, the cast would throw and `_performRefresh`'s caller would read
      // the throw as "session over" — signing out a user whose refresh had
      // actually just succeeded.
      wire(
        onMain: (_) => _bareJson(_envelope('EXPIRED_TOKEN'), 400),
        onSide: (options) => options.path.endsWith('/auth/refresh/')
            ? _bareJson({'access_token': 'fresh-token'}, 200)
            : _bareJson({'unread_count': 0}, 200),
      );

      return main.get<dynamic>(protectedPath).then((response) async {
        expect(response.statusCode, 200);
        expect(
          await storage.read(key: AppConstants.accessTokenKey),
          'fresh-token',
        );
        expect(expiries, isEmpty);
      });
    });

    test('a refresh 200 with no access_token ends the session', () async {
      wire(
        onMain: (_) => _bareJson(_envelope('EXPIRED_TOKEN'), 400),
        onSide: (_) => _json({'detail': 'ok'}, 200),
      );

      await expectLater(
        main.get<dynamic>(protectedPath),
        throwsA(isA<DioException>()),
      );

      expect(await storage.read(key: AppConstants.accessTokenKey), isNull);
      expect(expiries, [SessionExpiredReason.refreshFailed]);
    });
  });

  group('401 NOT_AUTHENTICATED also refreshes (§2.3)', () {
    test('a 401 with no readable code still attempts a refresh', () async {
      wire(
        onMain: (_) => ResponseBody.fromString('', 401),
        onSide: (options) => options.path.endsWith('/auth/refresh/')
            ? _json({'access_token': 'fresh-token'}, 200)
            : _json({'unread_count': 0}, 200),
      );

      final response = await main.get<dynamic>(protectedPath);

      expect(response.statusCode, 200);
      expect(
        await storage.read(key: AppConstants.accessTokenKey),
        'fresh-token',
      );
    });
  });

  group('unrecoverable states end the session', () {
    test('403 INVALID_TOKEN signs out without attempting a refresh', () async {
      // A structurally broken token is not something a refresh can fix.
      wire(
        onMain: (_) => _bareJson(_envelope('INVALID_TOKEN'), 403),
        onSide: (_) => _json({'access_token': 'never'}, 200),
      );

      await expectLater(
        main.get<dynamic>(protectedPath),
        throwsA(isA<DioException>()),
      );

      expect(sideAdapter.requests, isEmpty);
      expect(await storage.read(key: AppConstants.accessTokenKey), isNull);
      expect(expiries, [SessionExpiredReason.invalidToken]);
    });

    test('a dead refresh session signs out', () async {
      wire(
        onMain: (_) => _bareJson(_envelope('EXPIRED_TOKEN'), 400),
        onSide: (_) => _bareJson(_envelope('NOT_FOUND_OR_INACTIVE_SESSION'), 404),
      );

      await expectLater(
        main.get<dynamic>(protectedPath),
        throwsA(isA<DioException>()),
      );

      expect(await storage.read(key: AppConstants.accessTokenKey), isNull);
      expect(expiries, [SessionExpiredReason.refreshFailed]);
    });
  });

  group('errors that are none of the interceptor\'s business', () {
    test('a 500 is passed through untouched — no refresh, no sign-out', () async {
      // The avatar-presign 500 from the bug report sat in the same log; it
      // must not be mistaken for an auth problem.
      wire(
        onMain: (_) => _bareJson(_envelope('UNKNOWN_EXCEPTION'), 500),
        onSide: (_) => _json({'access_token': 'never'}, 200),
      );

      await expectLater(
        main.post<dynamic>('/profiles/avatar/presign/'),
        throwsA(isA<DioException>()),
      );

      expect(sideAdapter.requests, isEmpty);
      expect(
        await storage.read(key: AppConstants.accessTokenKey),
        'expired-token',
      );
      expect(expiries, isEmpty);
    });

    test('a 400 that is not EXPIRED_TOKEN does not refresh', () async {
      // Refreshing on any 400 would fire on every validation error.
      wire(
        onMain: (_) => _bareJson(_envelope('VALIDATION'), 400),
        onSide: (_) => _json({'access_token': 'never'}, 200),
      );

      await expectLater(
        main.get<dynamic>('/chats/'),
        throwsA(isA<DioException>()),
      );

      expect(sideAdapter.requests, isEmpty);
      expect(expiries, isEmpty);
    });

    test('a replay failing on its own merits does not sign the user out', () async {
      // The refresh worked, so the session is healthy; the retried request
      // simply failed for an unrelated reason.
      wire(
        onMain: (_) => _bareJson(_envelope('EXPIRED_TOKEN'), 400),
        onSide: (options) => options.path.endsWith('/auth/refresh/')
            ? _json({'access_token': 'fresh-token'}, 200)
            : _bareJson(_envelope('UNKNOWN_EXCEPTION'), 500),
      );

      await expectLater(
        main.get<dynamic>(protectedPath),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            500,
          ),
        ),
      );

      expect(
        await storage.read(key: AppConstants.accessTokenKey),
        'fresh-token',
      );
      expect(expiries, isEmpty);
    });
  });
}
