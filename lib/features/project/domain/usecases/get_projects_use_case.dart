import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `GET /projects/` 🔒 (api-docs §5.1).
class GetProjectsUseCase {
  final ProjectRepository _repository;

  GetProjectsUseCase(this._repository);

  Future<Either<Failure, PageResult<ProjectEntity>>> execute({
    String? name,
    String? slug,
    List<String>? tags,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) {
    final err = validatePaging(page, pageSize);
    if (err != null) return Future.value(Left(err));
    return _repository.getProjects(
      name: name,
      slug: slug,
      tags: tags,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
  }
}
