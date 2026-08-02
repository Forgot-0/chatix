import 'package:chatix/core/auth/session_events.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/network/interceptors/auth_interceptor.dart';
import 'package:chatix/core/network/interceptors/retry_interceptor.dart';
import 'package:chatix/core/network/interceptors/trailing_slash_interceptor.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_providers.g.dart';

/// Initialized in [main] — [PersistCookieJar] needs an app documents path.
final cookieJarProvider = Provider<CookieJar>((ref) {
  throw UnimplementedError(
    'cookieJarProvider must be overridden in main() after PersistCookieJar init',
  );
});

/// The auth-free [Dio] that [AuthInterceptor] uses for `POST /auth/refresh/`
/// and for replaying the request that just 401'd.
///
/// It deliberately shares exactly two things with [dioProvider] — the
/// `baseUrl` (the refresh endpoint is a normal `{BASE_URL}/api/v1` path) and
/// the [CookieJar] (the refresh token is an HttpOnly cookie, so without the
/// jar the refresh has nothing to authenticate with) — and deliberately
/// carries **no** [AuthInterceptor].
///
/// That omission is the whole point. [AuthInterceptor] is a
/// [QueuedInterceptor]: its `onError` holds dio's single callback slot for as
/// long as it is awaiting the refresh. Issuing the refresh on the *same*
/// client would queue that nested request's `onError` behind the outer one
/// that is waiting for it — a deadlock with no timeout, which would strike
/// precisely on the expired-session path this class exists to serve. See the
/// class doc on [AuthInterceptor].
///
/// [TrailingSlashInterceptor] is kept because it is a pure path normalizer
/// with no I/O of its own, and the replayed [RequestOptions] must be
/// normalized the same way the original was. [RetryInterceptor] is left off
/// on purpose: a refresh that fails should end the session immediately rather
/// than be retried behind the held queue slot.
final authSideChannelDioProvider = Provider<Dio>((ref) {
  final cookieJar = ref.watch(cookieJarProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(CookieManager(cookieJar));
  dio.interceptors.add(TrailingSlashInterceptor());

  return dio;
});

@riverpod
Dio dio(Ref ref) {
  final cookieJar = ref.watch(cookieJarProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      headers: const {
        // Default JSON headers. POST /auth/login/ must override to
        // application/x-www-form-urlencoded in the auth feature (api-docs §3.3).
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(CookieManager(cookieJar));
  dio.interceptors.add(TrailingSlashInterceptor());
  dio.interceptors.add(
    AuthInterceptor(
      // NOT `dio` — see [authSideChannelDioProvider]. Passing the client this
      // interceptor is installed on is what the compiler was rejecting here,
      // and it would have deadlocked dio's callback queue on every expired
      // session even if it had compiled.
      sideChannel: ref.watch(authSideChannelDioProvider),
      secureStorage: secureStorage,
      // The missing half of the "session expired mid-use" path. Without this
      // argument the interceptor still cleared the stored token, but nothing
      // in the app ever heard about it: `AuthController` kept its
      // `UserEntity`, the shell kept four tabs, and the router had no reason
      // to re-evaluate its redirect. Every screen would have had to notice
      // its own 401 — exactly what `core/auth/session_events.dart` exists to
      // avoid. Reading it here closes the loop:
      //
      //   interceptor -> sessionExpiredSignal -> AuthController (signed out)
      //               -> routerProvider.refreshListenable -> redirect /login
      //
      // `read`, not `watch`: the signal is a leaf provider that never
      // rebuilds, and watching it would needlessly tie Dio's lifetime to it.
      sessionExpiredSignal: ref.read(sessionExpiredSignalProvider),
    ),
  );
  dio.interceptors.add(RetryInterceptor(dio: dio));

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  return dio;
}

/// Thin wrapper around [Dio] that maps responses/errors into
/// `Either<Failure, dynamic>` per the api-docs §2 error envelope. Feature
/// datasources should depend on this instead of touching [Dio] directly.
final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});

/// A bare [Dio] instance with **no** `baseUrl` and **none** of
/// [dioProvider]'s interceptors (cookies, auth, retry, trailing-slash).
///
/// Exists for requests that must go straight to an absolute, pre-signed
/// third-party URL — profile avatar upload (api-docs §4.5 step 2) and,
/// later, chat attachment upload (api-docs §6.5) — where attaching our
/// `Authorization: Bearer` header or rewriting the path would break the
/// upload's own signature (api-docs §10.4). Only timeouts are shared with
/// the main client; nothing else about `{BASE_URL}/api/v1/*` requests
/// applies here.
final rawUploadDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      sendTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
    ),
  );
});
