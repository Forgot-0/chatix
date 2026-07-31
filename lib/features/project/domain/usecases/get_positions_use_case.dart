import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/project/domain/entities/position_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `GET /positions/` 🔓 public (api-docs §5.3).
class GetPositionsUseCase {
  final ProjectRepository _repository;

  GetPositionsUseCase(this._repository);

  Future<Either<Failure, PageResult<PositionEntity>>> execute({
    int? projectId,
    String? title,
    List<String>? requiredSkills,
    bool isOpen = true,
    PositionLocationType? locationType,
    PositionExpectedLoad? expectedLoad,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) {
    final err = validatePaging(page, pageSize);
    if (err != null) return Future.value(Left(err));
    return _repository.getPositions(
      projectId: projectId,
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
