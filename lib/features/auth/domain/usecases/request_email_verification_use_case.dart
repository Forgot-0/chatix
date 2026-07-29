import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';

/// `POST /auth/verifications/email/` (api-docs §3.6). Rate limit: 3/hour —
/// a `RateLimitFailure` here just means "try again later", surface it as-is.
class RequestEmailVerificationUseCase {
  final AuthRepository _repository;

  RequestEmailVerificationUseCase(this._repository);

  Future<Either<Failure, void>> execute({required String email}) {
    if (email.isEmpty) {
      return Future.value(const Left(InputFailure(message: 'Email cannot be empty')));
    }
    return _repository.requestEmailVerification(email: email);
  }
}
