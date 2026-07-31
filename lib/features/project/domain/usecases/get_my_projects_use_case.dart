import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `GET /projects/my/` 🔒 (api-docs §5.1).
class GetMyProjectsUseCase {
  final ProjectRepository _repository;

  GetMyProjectsUseCase(this._repository);

  Future<Either<Failure, PageResult<ProjectEntity>>> execute({
    int page = 1,
    int pageSize = 20,
  }) {
    final err = validatePaging(page, pageSize);
    if (err != null) return Future.value(Left(err));
    return _repository.getMyProjects(page: page, pageSize: pageSize);
  }
}
