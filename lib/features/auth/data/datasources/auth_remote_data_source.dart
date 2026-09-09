import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<Either<Failure, UserModel>> register({
    required String username,
    required String email,
    required String password,
    required String passwordRepeat,
  });

  Future<Either<Failure, String>> login({
    required String username,
    required String password,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, UserModel>> getCurrentUser();

  Future<Either<Failure, void>> requestEmailVerification({
    required String email,
  });

  Future<Either<Failure, void>> confirmEmailVerification({
    required String token,
  });

  Future<Either<Failure, void>> requestPasswordReset({required String email});

  Future<Either<Failure, void>> confirmPasswordReset({
    required String token,
    required String password,
    required String passwordRepeat,
  });

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
    return result.map(
      (data) => UserModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, String>> login({
    required String username,
    required String password,
  }) async {
    final result = await _apiClient.post(
      '/auth/login/',
      data: {'username': username, 'password': password},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return result.map(
      (data) => (data as Map<String, dynamic>)['access_token'] as String,
    );
  }

  @override
  Future<Either<Failure, void>> logout() async {
    final result = await _apiClient.post('/auth/logout/');
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, UserModel>> getCurrentUser() async {
    final result = await _apiClient.get('/users/me/');
    return result.map(
      (data) => UserModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, void>> requestEmailVerification({
    required String email,
  }) async {
    final result = await _apiClient.post(
      '/auth/verifications/email/',
      data: {'email': email},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> confirmEmailVerification({
    required String token,
  }) async {
    final result = await _apiClient.post(
      '/auth/verifications/email/verify/',
      data: {'token': token},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> requestPasswordReset({
    required String email,
  }) async {
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
    return result.map(
      (data) => (data as Map<String, dynamic>)['url'] as String,
    );
  }
}

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(apiClientProvider));
});
