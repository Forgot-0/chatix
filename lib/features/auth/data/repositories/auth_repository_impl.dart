import 'package:chatix/features/auth/data/models/user_model.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/data/models/session_model.dart';
import 'package:chatix/features/auth/domain/entities/session_entity.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/storage/secure_storage_service.dart';
import 'package:chatix/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorageService;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService secureStorageService,
  }) : _remoteDataSource = remoteDataSource,
       _secureStorageService = secureStorageService;

  @override
  Future<Either<Failure, UserEntity>> register({
    required String username,
    required String email,
    required String password,
    required String passwordRepeat,
  }) async {
    final result = await _remoteDataSource.register(
      username: username,
      email: email,
      password: password,
      passwordRepeat: passwordRepeat,
    );
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, void>> login({
    required String username,
    required String password,
  }) async {
    final result = await _remoteDataSource.login(
      username: username,
      password: password,
    );

    return result.fold((failure) async => Left(failure), (accessToken) async {
      await _secureStorageService.write(
        key: AppConstants.accessTokenKey,
        value: accessToken,
      );
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> logout() async {
    final result = await _remoteDataSource.logout();

    return result.fold(
      (failure) async {
        if (failure is ApiFailure) {
          await _secureStorageService.delete(key: AppConstants.accessTokenKey);
        }
        return Left(failure);
      },
      (_) async {
        await _secureStorageService.delete(key: AppConstants.accessTokenKey);
        return const Right(null);
      },
    );
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    final result = await _remoteDataSource.getCurrentUser();
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, void>> requestEmailVerification({
    required String email,
  }) {
    return _remoteDataSource.requestEmailVerification(email: email);
  }

  @override
  Future<Either<Failure, void>> confirmEmailVerification({
    required String token,
  }) {
    return _remoteDataSource.confirmEmailVerification(token: token);
  }

  @override
  Future<Either<Failure, void>> requestPasswordReset({required String email}) {
    return _remoteDataSource.requestPasswordReset(email: email);
  }

  @override
  Future<Either<Failure, void>> confirmPasswordReset({
    required String token,
    required String password,
    required String passwordRepeat,
  }) {
    return _remoteDataSource.confirmPasswordReset(
      token: token,
      password: password,
      passwordRepeat: passwordRepeat,
    );
  }

  @override
  Future<Either<Failure, String>> getOAuthUrl({
    required String provider,
    bool connect = false,
  }) {
    return _remoteDataSource.getOAuthUrl(provider: provider, connect: connect);
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getMySessions() async {
    final result = await _remoteDataSource.fetchMySessions();
    return result.map(
      (models) => models.map((model) => model.toEntity()).toList(),
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    secureStorageService: ref.watch(secureStorageServiceProvider),
  );
});
