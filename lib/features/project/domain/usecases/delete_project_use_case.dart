import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `DELETE /projects/{project_id}/` 🔒 (api-docs §5.1).
class DeleteProjectUseCase {
  final ProjectRepository _repository;

  DeleteProjectUseCase(this._repository);

  Future<Either<Failure, void>> execute(int projectId) {
    final err = validatePositiveId(projectId, 'projectId');
    if (err != null) return Future.value(Left(err));
    return _repository.deleteProject(projectId);
  }
}
