import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';

/// `GET /users/me/` (api-docs §3.9) — the single source of truth for "who
/// is logged in", used both at app startup and right after login/register.
class GetCurrentUserUseCase {
  final AuthRepository _repository;

  GetCurrentUserUseCase(this._repository);

  Future<Either<Failure, UserEntity>> execute() {
    return _repository.getCurrentUser();
  }
}
