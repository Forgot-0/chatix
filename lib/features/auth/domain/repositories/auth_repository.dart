import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/session_entity.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> register({
    required String username,
    required String email,
    required String password,
    required String passwordRepeat,
  });

  Future<Either<Failure, void>> login({
    required String username,
    required String password,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, UserEntity>> getCurrentUser();

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

  Future<Either<Failure, List<SessionEntity>>> getMySessions();
}
