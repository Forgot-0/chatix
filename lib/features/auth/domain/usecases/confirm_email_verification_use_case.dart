import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';

class ConfirmEmailVerificationUseCase {
  final AuthRepository _repository;

  ConfirmEmailVerificationUseCase(this._repository);

  Future<Either<Failure, void>> execute({required String token}) {
    if (token.isEmpty) {
      return Future.value(
        const Left(InputFailure(message: 'Token cannot be empty')),
      );
    }
    return _repository.confirmEmailVerification(token: token);
  }
}
