import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/auth/data/models/user_model.dart';

/// Talks to `/auth/*` and `/users/*` (api-docs §3) via [ApiClient], which
/// already maps Dio responses/errors into `Either<Failure, dynamic>`
/// (`ApiFailure`/`RateLimitFailure`/`NetworkFailure`/...). This layer's only
/// job is building the right request and parsing the JSON payload into a
/// [UserModel] (or the bare value the endpoint returns) — no persistence,
/// no business logic. That belongs to [AuthRepositoryImpl].
abstract class AuthRemoteDataSource {
  /// `POST /users/register/` (api-docs §3.2).
  Future<Either<Failure, UserModel>> register({
    required String username,
    required String email,
    required String password,
    required String passwordRepeat,
  });

  /// `POST /auth/login/` (api-docs §3.3) — form-urlencoded, not JSON.
  /// Returns the raw `access_token`; persistence is the repository's job.
  Future<Either<Failure, String>> login({
    required String username,
    required String password,
  });

  /// `POST /auth/logout/` (api-docs §3.5).
  Future<Either<Failure, void>> logout();

  /// `GET /users/me/` (api-docs §3.9).
  Future<Either<Failure, UserModel>> getCurrentUser();

  /// `POST /auth/verifications/email/` (api-docs §3.6).
  Future<Either<Failure, void>> requestEmailVerification({required String email});

  /// `POST /auth/verifications/email/verify/` (api-docs §3.6).
  Future<Either<Failure, void>> confirmEmailVerification({required String token});

  /// `POST /auth/password-resets/` (api-docs §3.7).
  Future<Either<Failure, void>> requestPasswordReset({required String email});

  /// `POST /auth/password-resets/confirm/` (api-docs §3.7).
  Future<Either<Failure, void>> confirmPasswordReset({
    required String token,
    required String password,
    required String passwordRepeat,
  });

  /// `GET /auth/oauth/{provider}/authorize/` or `.../authorize/connect/`
  /// (api-docs §3.8). Returns the URL to open in a browser/WebView.
  Future<Either<Failure, String>> getOAuthUrl({
    required String provider,
    bool connect = false,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl(this._apiClient);

  @override
  Future<Either<Failure, UserModel>> register({
    required String username,
    required String email,
    required String password,
    required String passwordRepeat,
  }) async {
    final result = await _apiClient.post(
      '/users/register/',
      data: {
        'username': username,
        'email': email,
        'password': password,
        'password_repeat': passwordRepeat,
      },
    );
    return result.map((data) => UserModel.fromJson(data as Map<String, dynamic>));
  }

  @override
  Future<Either<Failure, String>> login({
    required String username,
    required String password,
  }) async {
    // api-docs §3.3 ⚠️: must be application/x-www-form-urlencoded, NOT
    // JSON, and NOT multipart (which is what dio's FormData would send).
    // Passing a plain Map with this content type makes dio urlencode it.
    final result = await _apiClient.post(
      '/auth/login/',
      data: {'username': username, 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return result.map((data) => (data as Map<String, dynamic>)['access_token'] as String);
  }

  @override
  Future<Either<Failure, void>> logout() async {
    final result = await _apiClient.post('/auth/logout/');
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, UserModel>> getCurrentUser() async {
    final result = await _apiClient.get('/users/me/');
    return result.map((data) => UserModel.fromJson(data as Map<String, dynamic>));
  }

  @override
  Future<Either<Failure, void>> requestEmailVerification({required String email}) async {
    final result = await _apiClient.post(
      '/auth/verifications/email/',
      data: {'email': email},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> confirmEmailVerification({required String token}) async {
    final result = await _apiClient.post(
      '/auth/verifications/email/verify/',
      data: {'token': token},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> requestPasswordReset({required String email}) async {
    final result = await _apiClient.post(
      '/auth/password-resets/',
      data: {'email': email},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> confirmPasswordReset({
    required String token,
    required String password,
    required String passwordRepeat,
  }) async {
    final result = await _apiClient.post(
      '/auth/password-resets/confirm/',
      data: {
        'token': token,
        'password': password,
        'password_repeat': passwordRepeat,
      },
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, String>> getOAuthUrl({
    required String provider,
    bool connect = false,
  }) async {
    final path = connect
        ? '/auth/oauth/$provider/authorize/connect/'
        : '/auth/oauth/$provider/authorize/';
    final result = await _apiClient.get(path);
    return result.map((data) => (data as Map<String, dynamic>)['url'] as String);
  }
}

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(apiClientProvider));
});
