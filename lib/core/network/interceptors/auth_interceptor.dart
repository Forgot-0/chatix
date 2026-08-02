import 'package:chatix/core/auth/session_events.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/network/api_path.dart';
import 'package:chatix/core/storage/secure_storage_service.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:synchronized/synchronized.dart';

/// Attaches access tokens and refreshes them via HttpOnly refresh cookie.
///
/// Refresh token never touches Dart storage — only [PersistCookieJar] sends it.
///
/// ### Announcing the end of a session
///
/// Clearing the stored token is not enough on its own: the rest of the app
/// (an `AuthController` still holding a `UserEntity`, a shell still drawing
/// four tabs) has no way to find out. Whenever this interceptor concludes the
/// session is unrecoverable it therefore also fires [sessionExpiredSignal],
/// which `AuthController` turns into a signed-out state and the router turns
/// into a redirect to `/login` — from anywhere, including code paths with no
/// `BuildContext`. See `core/auth/session_events.dart` for why this is a bus
/// rather than a direct call.
///
/// ### ⚠️ Why [sideChannel] must not be the main [Dio]
///
/// This is a [QueuedInterceptor]: dio runs its `onRequest`/`onError` callbacks
/// one at a time, and the slot is held for as long as the callback's future is
/// unresolved. [onError] therefore *owns* the queue while it awaits the
/// refresh.
///
/// If the refresh (or the replay of the original request) were issued on the
/// same [Dio], it would carry this very interceptor. As long as those nested
/// requests succeed nothing bad shows up — only `onRequest` runs, and dio lets
/// it through. But the moment one of them **fails**, its `onError` is queued
/// behind the outer `onError` that is still waiting for it, and the two wait
/// on each other forever: no timeout fires, the caller's future never
/// completes, and every later request piles up behind the jammed queue until
/// the whole app is frozen.
///
/// That is precisely the "session expired" path — the case this class exists
/// to handle — so the deadlock would hit exactly when it hurts most. Both the
/// `POST /auth/refresh/` and the replay consequently go through
/// [sideChannel]: a separate [Dio] that shares the base URL and the cookie jar
/// (the refresh token is an HttpOnly cookie, so the jar is mandatory) but
/// carries **no** `AuthInterceptor`. See `network_providers.dart`, and
/// `test/core/network/auth_refresh_flow_test.dart` for the regression tests
/// that pin all four failure shapes.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required Dio sideChannel,
    required SecureStorageService secureStorage,
    SessionExpiredSignal? sessionExpiredSignal,
  }) : _sideChannel = sideChannel,
       _secureStorage = secureStorage,
       _sessionExpiredSignal = sessionExpiredSignal;

  /// Auth-free [Dio] used for the refresh call and the replay. Never the
  /// client this interceptor is installed on — see the class doc.
  final Dio _sideChannel;
  final SecureStorageService _secureStorage;

  /// Nullable so the existing tests (and any non-app usage) can construct an
  /// interceptor without wiring the whole signal; when absent, behaviour is
  /// exactly what it was before — clear the token, propagate the error.
  final SessionExpiredSignal? _sessionExpiredSignal;

  final Lock _refreshLock = Lock();

  static const _refreshPath = '/auth/refresh/';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublicPath(options.path)) {
      final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.requestOptions.extra['skipAuthRefresh'] == true) {
      handler.next(err);
      return;
    }

    if (_isInvalidToken(err)) {
      // api-docs §2.3: a `403 INVALID_TOKEN` means the token is structurally
      // unusable, so there is nothing a refresh could fix.
      await _endSession(SessionExpiredReason.invalidToken);
      handler.next(err);
      return;
    }

    if (!_shouldAttemptRefresh(err)) {
      handler.next(err);
      return;
    }

    // Two failures live in this block and they must not be conflated: the
    // refresh dying means the session is over, while the *replay* dying is
    // just the original request failing for its own reasons. Signing a valid
    // user out because their `GET /projects/` happened to 500 on the retry
    // would be a nasty bug, so they are caught separately.
    final String? newToken;
    try {
      newToken = await _refreshOrReuse(err.requestOptions);
    } catch (e, stackTrace) {
      // A shape `_performRefresh` could not classify: transport error,
      // malformed body, an unexpected status. Treat as session-over, but never
      // silently — this is the branch that used to be a bare `catch (_)`.
      Logger.error(
        'AuthInterceptor: token refresh threw for '
        '${err.requestOptions.method} ${err.requestOptions.path}; '
        'ending the session',
        e,
        stackTrace,
      );
      await _endSession(SessionExpiredReason.refreshFailed);
      handler.next(err);
      return;
    }

    if (newToken == null) {
      // The refresh came back with a terminal answer (dead session, rejected
      // cookie) — the "session expired mid-use" case.
      Logger.info(
        'AuthInterceptor: refresh rejected, session is over '
        '(${err.requestOptions.path})',
      );
      await _endSession(SessionExpiredReason.refreshFailed);
      handler.next(err);
      return;
    }

    try {
      final requestOptions = err.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $newToken';
      handler.resolve(await _sideChannel.fetch(requestOptions));
    } on DioException catch (e) {
      // The replay failed on its own merits. The session is fine; hand back
      // the replay's error, which is more accurate than the stale 401.
      Logger.warning(
        'AuthInterceptor: replay of ${err.requestOptions.method} '
        '${err.requestOptions.path} failed after a successful refresh '
        '(${e.response?.statusCode})',
      );
      handler.next(e);
    } catch (e, stackTrace) {
      Logger.error(
        'AuthInterceptor: replay of ${err.requestOptions.method} '
        '${err.requestOptions.path} threw after a successful refresh',
        e,
        stackTrace,
      );
      handler.next(err);
    }
  }

  bool _isPublicPath(String path) {
    final normalized = buildPath(path);
    return normalized.startsWith('/auth/login/') ||
        normalized.startsWith('/auth/refresh/') ||
        normalized.startsWith('/auth/register/') ||
        normalized.startsWith('/users/register/');
  }

  bool _shouldAttemptRefresh(DioException err) {
    if (buildPath(err.requestOptions.path) == _refreshPath) {
      return false;
    }

    final statusCode = err.response?.statusCode;
    final code = _readErrorCode(err.response?.data);

    if (statusCode == 401) {
      return code == null || code == 'NOT_AUTHENTICATED';
    }

    if (statusCode == 400 && code == 'EXPIRED_TOKEN') {
      return true;
    }

    return false;
  }

  bool _isInvalidToken(DioException err) {
    final statusCode = err.response?.statusCode;
    final code = _readErrorCode(err.response?.data);
    return statusCode == 403 && code == 'INVALID_TOKEN';
  }

  String? _readErrorCode(dynamic data) {
    if (data is! Map) {
      return null;
    }
    final error = data['error'];
    if (error is! Map) {
      return null;
    }
    final code = error['code'];
    return code is String ? code : null;
  }

  /// Refreshes once for a burst of requests that all died on the same stale
  /// token.
  ///
  /// [Lock] alone only makes the refreshes *sequential*, not *singular*: five
  /// requests that 401 together would each take the lock in turn and each fire
  /// its own `POST /auth/refresh/`. That is not merely wasteful — backends
  /// that rotate the refresh cookie on use (§3.4) invalidate it on the first
  /// call, so refreshes 2..5 come back `NOT_FOUND_OR_INACTIVE_SESSION` and log
  /// out a user whose session was perfectly healthy a moment ago.
  ///
  /// So inside the lock we first re-read storage: if the token there is no
  /// longer the one this request went out with, a sibling already did the work
  /// and its result is reused.
  Future<String?> _refreshOrReuse(RequestOptions options) {
    final sentWith = options.headers[_authHeader] as String?;

    return _refreshLock.synchronized(() async {
      final stored = await _secureStorage.read(key: AppConstants.accessTokenKey);
      if (stored != null &&
          stored.isNotEmpty &&
          '$_bearerPrefix$stored' != sentWith) {
        Logger.debug(
          'AuthInterceptor: reusing the token a sibling request just '
          'refreshed (${options.path})',
        );
        return stored;
      }
      return _performRefresh();
    });
  }

  Future<String?> _performRefresh() async {
    try {
      final response = await _sideChannel.post<Map<String, dynamic>>(
        _refreshPath,
        options: Options(extra: {'skipAuthRefresh': true}),
      );
      final accessToken = response.data?['access_token'];
      if (accessToken is! String || accessToken.isEmpty) {
        return null;
      }

      await _secureStorage.write(
        key: AppConstants.accessTokenKey,
        value: accessToken,
      );
      return accessToken;
    } on DioException catch (e) {
      if (_isRefreshTerminalFailure(e)) {
        return null;
      }
      rethrow;
    }
  }

  bool _isRefreshTerminalFailure(DioException err) {
    final statusCode = err.response?.statusCode;
    final code = _readErrorCode(err.response?.data);

    if (statusCode == 404 && code == 'NOT_FOUND_OR_INACTIVE_SESSION') {
      return true;
    }

    if (statusCode == 400 &&
        (code == 'INVALID_TOKEN' || code == 'EXPIRED_TOKEN')) {
      return true;
    }

    return false;
  }

  /// Drops the local session and tells the app about it.
  ///
  /// Order matters: the token is deleted **before** the signal is emitted, so
  /// that anything reacting to the signal (`AuthController` re-reading
  /// storage, a retry) can never observe a session that is half gone.
  Future<void> _endSession(SessionExpiredReason reason) async {
    await _clearSession();
    _sessionExpiredSignal?.notify(reason);
  }

  Future<void> _clearSession() async {
    await _secureStorage.delete(key: AppConstants.accessTokenKey);
  }
}
