import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';

/// `POST /auth/password-resets/` (api-docs §3.7). Rate limit: 3/hour.
class RequestPasswordResetUseCase {
  final AuthRepository _repository;

  RequestPasswordResetUseCase(this._repository);

  Future<Either<Failure, void>> execute({required String email}) {
    if (email.isEmpty) {
      return Future.value(const Left(InputFailure(message: 'Email cannot be empty')));
    }
    return _repository.requestPasswordReset(email: email);
  }
}
