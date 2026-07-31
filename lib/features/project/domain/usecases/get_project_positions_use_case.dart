import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/project/domain/entities/position_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `GET /projects/{project_id}/positions/` 🔒 (api-docs §5.3).
class GetProjectPositionsUseCase {
  final ProjectRepository _repository;

  GetProjectPositionsUseCase(this._repository);

  Future<Either<Failure, PageResult<PositionEntity>>> execute(
    int projectId, {
    String? title,
    List<String>? requiredSkills,
    bool isOpen = true,
    PositionLocationType? locationType,
    PositionExpectedLoad? expectedLoad,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) {
    final e1 = validatePositiveId(projectId, 'projectId');
    if (e1 != null) return Future.value(Left(e1));
    final e2 = validatePaging(page, pageSize);
    if (e2 != null) return Future.value(Left(e2));
    return _repository.getProjectPositions(
      projectId,
      title: title,
      requiredSkills: requiredSkills,
      isOpen: isOpen,
      locationType: locationType,
      expectedLoad: expectedLoad,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
  }
}
