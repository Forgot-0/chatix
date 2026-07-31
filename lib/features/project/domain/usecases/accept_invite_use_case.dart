import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `POST /projects/{project_id}/members/accept/` 🔒 — accept your own invite
/// (api-docs §5.2).
class AcceptInviteUseCase {
  final ProjectRepository _repository;

  AcceptInviteUseCase(this._repository);

  Future<Either<Failure, void>> execute(int projectId) {
    final err = validatePositiveId(projectId, 'projectId');
    if (err != null) return Future.value(Left(err));
    return _repository.acceptInvite(projectId);
  }
}
