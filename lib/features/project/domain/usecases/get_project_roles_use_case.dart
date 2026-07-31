import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/project/domain/entities/project_role_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `GET /project_roles/` 🔓 public, read-only (api-docs §5.5). There is no
/// create/update use case — the backend exposes no such endpoints.
class GetProjectRolesUseCase {
  final ProjectRepository _repository;

  GetProjectRolesUseCase(this._repository);

  Future<Either<Failure, PageResult<ProjectRoleEntity>>> execute({
    String? name,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) {
    final err = validatePaging(page, pageSize);
    if (err != null) return Future.value(Left(err));
    return _repository.getProjectRoles(name: name, page: page, pageSize: pageSize, sort: sort);
  }
}
