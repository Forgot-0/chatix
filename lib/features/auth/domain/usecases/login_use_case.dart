import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<Either<Failure, void>> execute({
    required String username,
    required String password,
  }) {
    if (username.isEmpty || password.isEmpty) {
      return Future.value(
        const Left(InputFailure(message: 'Username and password cannot be empty')),
      );
    }

    return _repository.login(username: username, password: password);
  }
}
