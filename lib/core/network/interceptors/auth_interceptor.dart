import 'package:chatix/core/auth/session_events.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/network/api_path.dart';
import 'package:chatix/core/storage/secure_storage_service.dart';
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
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required Dio dio,
    required SecureStorageService secureStorage,
    SessionExpiredSignal? sessionExpiredSignal,
  }) : _dio = dio,
       _secureStorage = secureStorage,
       _sessionExpiredSignal = sessionExpiredSignal;

  final Dio _dio;
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

    try {
      final newToken = await _refreshLock.synchronized(_performRefresh);
      if (newToken == null) {
        // The refresh itself came back with a terminal answer (dead session,
        // rejected cookie) — this is the "session expired mid-use" case.
        await _endSession(SessionExpiredReason.refreshFailed);
        handler.next(err);
        return;
      }

      final requestOptions = err.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $newToken';
      final response = await _dio.fetch(requestOptions);
      handler.resolve(response);
    } catch (_) {
      await _endSession(SessionExpiredReason.refreshFailed);
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

  Future<String?> _performRefresh() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
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
