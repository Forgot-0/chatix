import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';

/// `POST /auth/password-resets/confirm/` (api-docs §3.7).
class ConfirmPasswordResetUseCase {
  final AuthRepository _repository;

  ConfirmPasswordResetUseCase(this._repository);

  Future<Either<Failure, void>> execute({
    required String token,
    required String password,
    required String passwordRepeat,
  }) {
    if (token.isEmpty || password.isEmpty || passwordRepeat.isEmpty) {
      return Future.value(const Left(InputFailure(message: 'All fields are required')));
    }
    if (password != passwordRepeat) {
      return Future.value(const Left(InputFailure(message: 'Passwords do not match')));
    }
    return _repository.confirmPasswordReset(
      token: token,
      password: password,
      passwordRepeat: passwordRepeat,
    );
  }
}
