import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `GET /projects/{project_id}/` 🔒 (api-docs §5.1).
class GetProjectUseCase {
  final ProjectRepository _repository;

  GetProjectUseCase(this._repository);

  Future<Either<Failure, ProjectEntity>> execute(int projectId) {
    final err = validatePositiveId(projectId, 'projectId');
    if (err != null) return Future.value(Left(err));
    return _repository.getProject(projectId);
  }
}
