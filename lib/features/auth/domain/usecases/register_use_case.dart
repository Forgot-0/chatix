import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;

  RegisterUseCase(this._repository);

  Future<Either<Failure, UserEntity>> execute({
    required String username,
    required String email,
    required String password,
    required String passwordRepeat,
  }) {
    if (username.isEmpty || email.isEmpty || password.isEmpty || passwordRepeat.isEmpty) {
      return Future.value(
        const Left(InputFailure(message: 'All fields are required')),
      );
    }

    // Fast local check mirroring the backend's own PASSWORD_MISMATCH rule
    // (api-docs §3.2) — avoids a wasted round trip. The full password
    // complexity rule is enforced client-side in the form validators
    // (flutter_form_builder) so the user gets feedback before submitting.
    if (password != passwordRepeat) {
      return Future.value(
        const Left(InputFailure(message: 'Passwords do not match')),
      );
    }

    return _repository.register(
      username: username,
      email: email,
      password: password,
      passwordRepeat: passwordRepeat,
    );
  }
}
