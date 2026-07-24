import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/network/api_path.dart';
import 'package:chatix/core/storage/secure_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:synchronized/synchronized.dart';

/// Attaches access tokens and refreshes them via HttpOnly refresh cookie.
///
/// Refresh token never touches Dart storage — only [PersistCookieJar] sends it.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required Dio dio,
    required SecureStorageService secureStorage,
  }) : _dio = dio,
       _secureStorage = secureStorage;

  final Dio _dio;
  final SecureStorageService _secureStorage;
  final Lock _refreshLock = Lock();

  static const _refreshPath = '/auth/refresh/';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublicPath(options.path)) {
      final token = await _secureStorage.read(
        key: AppConstants.accessTokenKey,
      );
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
      await _clearSession();
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
        await _clearSession();
        handler.next(err);
        return;
      }

      final requestOptions = err.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $newToken';
      final response = await _dio.fetch(requestOptions);
      handler.resolve(response);
    } catch (_) {
      await _clearSession();
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
      return code == null || code == 'NOT_AUTHNTICATED';
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

  Future<void> _clearSession() async {
    await _secureStorage.delete(key: AppConstants.accessTokenKey);
  }
}
