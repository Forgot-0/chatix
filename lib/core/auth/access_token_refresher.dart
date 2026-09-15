import 'package:dio/dio.dart';
import 'package:synchronized/synchronized.dart';

import 'package:chatix/core/auth/jwt.dart';
import 'package:chatix/core/auth/session_events.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/network/error_envelope.dart';
import 'package:chatix/core/storage/secure_storage_service.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/socket_token_source.dart';

/// The one place the access token is renewed.
///
/// `POST /auth/refresh/` reads its refresh token from an HttpOnly cookie
/// (api-docs §0), so renewing is a request with no body and no visible
/// credential — which is exactly why it must not be made twice at once. Two
/// callers arriving together share one request through [_lock], and a caller
/// that arrives just after another finished is handed what that one stored
/// instead of asking again.
///
/// Both halves of the client come through here: the HTTP interceptor, when a
/// request comes back `401`/`EXPIRED_TOKEN`, and the socket, which cannot
/// retry a rejected handshake the way a request can and so has to know the
/// token is good *before* connecting (api-docs §6.1).
class AccessTokenRefresher implements SocketTokenSource {
  AccessTokenRefresher({
    required Dio sideChannel,
    required SecureStorageService secureStorage,
    SessionExpiredSignal? sessionExpiredSignal,
  }) : _sideChannel = sideChannel,
       _secureStorage = secureStorage,
       _sessionExpiredSignal = sessionExpiredSignal;

  final Dio _sideChannel;
  final SecureStorageService _secureStorage;
  final SessionExpiredSignal? _sessionExpiredSignal;

  final Lock _lock = Lock();

  static const String _refreshPath = '/auth/refresh/';

  /// What is in storage, whatever state it is in.
  Future<String?> stored() =>
      _secureStorage.read(key: AppConstants.accessTokenKey);

  /// A token good to use now, renewing it first if it is not.
  ///
  /// The five-minute lifetime (api-docs §0) means a token read from storage
  /// after any kind of pause is usually already dead. Checking `exp` before
  /// reaching for the network is what keeps this cheap in the common case and
  /// correct in the one that matters.
  @override
  Future<String?> token({bool forceRefresh = false}) async {
    final current = await stored();

    if (!forceRefresh && !Jwt.isExpired(current)) return current;

    try {
      return await refresh(knownStale: current);
    } on DioException catch (error) {
      // The refresh itself could not be made — no network, a timeout. That is
      // not the session ending, and treating it as one would sign people out
      // for going through a tunnel. The caller retries.
      Logger.warning(
        'AccessTokenRefresher: could not renew the token right now '
        '(${error.type.name})',
      );
      return null;
    }
  }

  /// Renews the token, or hands back the one a sibling just renewed.
  ///
  /// [knownStale] is the token the caller already found wanting. If storage
  /// holds something else by the time the lock is taken, that something else
  /// is the answer — somebody refreshed while this caller was queued.
  ///
  /// Returns null when the session is genuinely over, having ended it.
  /// Rethrows anything that merely failed to happen.
  Future<String?> refresh({String? knownStale}) {
    return _lock.synchronized(() async {
      final current = await stored();
      if (current != null && current.isNotEmpty && current != knownStale) {
        Logger.debug('AccessTokenRefresher: reusing a sibling\'s fresh token');
        return current;
      }

      return _perform();
    });
  }

  Future<String?> _perform() async {
    try {
      final response = await _sideChannel.post<dynamic>(
        _refreshPath,
        options: Options(extra: const {'skipAuthRefresh': true}),
      );

      final accessToken = decodeResponseBody(response.data)?['access_token'];
      if (accessToken is! String || accessToken.isEmpty) {
        await _endSession(SessionExpiredReason.refreshFailed);
        return null;
      }

      await _secureStorage.write(
        key: AppConstants.accessTokenKey,
        value: accessToken,
      );
      return accessToken;
    } on DioException catch (error) {
      if (!_isTerminal(error)) rethrow;

      Logger.info(
        'AccessTokenRefresher: refresh refused, the session is over '
        '(${readErrorCode(error.response?.data) ?? error.response?.statusCode})',
      );
      await _endSession(SessionExpiredReason.refreshFailed);
      return null;
    }
  }

  /// Whether the server refused in a way that means "sign in again" rather
  /// than "try later" (api-docs §2.3, §2.4).
  bool _isTerminal(DioException error) {
    final status = error.response?.statusCode;
    final code = readErrorCode(error.response?.data);

    if (status == 404 && code == 'NOT_FOUND_OR_INACTIVE_SESSION') return true;
    if (status == 400 && (code == 'INVALID_TOKEN' || code == 'EXPIRED_TOKEN')) {
      return true;
    }
    if (status == 401 || status == 403) return true;

    return false;
  }

  Future<void> _endSession(SessionExpiredReason reason) async {
    await _secureStorage.delete(key: AppConstants.accessTokenKey);
    _sessionExpiredSignal?.notify(reason);
  }
}
