import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;

  RegisterUseCase(this._repository);

  Future<Either<Failure, UserEntity>> execute({
    required String name,
    required String email,
    required String password,
  }) {
    // Add any validation logic here if needed
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      return Future.value(
        const Left(
          InputFailure(message: 'Name, email, and password cannot be empty'),
        ),
      );
    }

    return _repository.register(name: name, email: email, password: password);
  }
}
