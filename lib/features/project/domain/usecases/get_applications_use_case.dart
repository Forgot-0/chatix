import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/project/domain/entities/application_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `GET /applications/` 🔒 (api-docs §5.4).
class GetApplicationsUseCase {
  final ProjectRepository _repository;

  GetApplicationsUseCase(this._repository);

  Future<Either<Failure, PageResult<ApplicationEntity>>> execute({
    int? projectId,
    String? positionId,
    int? candidateId,
    ApplicationStatus? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) {
    final err = validatePaging(page, pageSize);
    if (err != null) return Future.value(Left(err));
    return _repository.getApplications(
      projectId: projectId,
      positionId: positionId,
      candidateId: candidateId,
      status: status,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
  }
}
