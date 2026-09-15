import 'package:chatix/core/auth/access_token_refresher.dart';
import 'package:chatix/core/auth/session_events.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/network/api_path.dart';
import 'package:chatix/core/network/error_envelope.dart';
import 'package:chatix/core/storage/secure_storage_service.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:dio/dio.dart';

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required Dio sideChannel,
    required SecureStorageService secureStorage,
    SessionExpiredSignal? sessionExpiredSignal,
    AccessTokenRefresher? refresher,
  }) : _sideChannel = sideChannel,
       _secureStorage = secureStorage,
       _sessionExpiredSignal = sessionExpiredSignal,
       _refresher =
           refresher ??
           AccessTokenRefresher(
             sideChannel: sideChannel,
             secureStorage: secureStorage,
             sessionExpiredSignal: sessionExpiredSignal,
           );

  final Dio _sideChannel;
  final SecureStorageService _secureStorage;

  final SessionExpiredSignal? _sessionExpiredSignal;

  /// Shared with the socket, so a renewal started by a request and one
  /// started by a reconnect are the same renewal rather than two.
  final AccessTokenRefresher _refresher;

  static const _refreshPath = '/auth/refresh/';

  static const _authHeader = 'Authorization';
  static const _bearerPrefix = 'Bearer ';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublicPath(options.path)) {
      final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
      if (token != null && token.isNotEmpty) {
        options.headers[_authHeader] = '$_bearerPrefix$token';
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
      await _endSession(SessionExpiredReason.invalidToken);
      handler.next(err);
      return;
    }

    if (!_shouldAttemptRefresh(err)) {
      handler.next(err);
      return;
    }

    final String? newToken;
    try {
      newToken = await _refreshOrReuse(err.requestOptions);
    } catch (e, stackTrace) {
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
      // The refresher has already cleared the token and said so — it is the
      // one that knows whether a refusal was terminal. Saying it twice would
      // reach the session-expiry listeners twice.
      Logger.info(
        'AuthInterceptor: refresh rejected, session is over '
        '(${err.requestOptions.path})',
      );
      handler.next(err);
      return;
    }

    try {
      final requestOptions = err.requestOptions;
      requestOptions.headers[_authHeader] = '$_bearerPrefix$newToken';
      handler.resolve(await _sideChannel.fetch(requestOptions));
    } on DioException catch (e) {
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

  String? _readErrorCode(dynamic data) => readErrorCode(data);

  Future<String?> _refreshOrReuse(RequestOptions options) {
    final sentWith = options.headers[_authHeader] as String?;
    final sentToken = sentWith != null && sentWith.startsWith(_bearerPrefix)
        ? sentWith.substring(_bearerPrefix.length)
        : null;

    return _refresher.refresh(knownStale: sentToken);
  }

  Future<void> _endSession(SessionExpiredReason reason) async {
    await _clearSession();
    _sessionExpiredSignal?.notify(reason);
  }

  Future<void> _clearSession() async {
    await _secureStorage.delete(key: AppConstants.accessTokenKey);
  }
}
