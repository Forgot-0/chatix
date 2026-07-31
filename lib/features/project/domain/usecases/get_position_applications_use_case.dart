import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/project/domain/entities/application_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `GET /positions/{position_id}/applications/` 🔒 (api-docs §5.3) — for the
/// position owner/maintainer to review incoming applications.
class GetPositionApplicationsUseCase {
  final ProjectRepository _repository;

  GetPositionApplicationsUseCase(this._repository);

  Future<Either<Failure, PageResult<ApplicationEntity>>> execute(
    String positionId, {
    int? projectId,
    int? candidateId,
    ApplicationStatus? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) {
    final e1 = validateStringId(positionId, 'positionId');
    if (e1 != null) return Future.value(Left(e1));
    final e2 = validatePaging(page, pageSize);
    if (e2 != null) return Future.value(Left(e2));
    return _repository.getPositionApplications(
      positionId,
      projectId: projectId,
      candidateId: candidateId,
      status: status,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
  }
}
