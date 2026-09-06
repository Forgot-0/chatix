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
