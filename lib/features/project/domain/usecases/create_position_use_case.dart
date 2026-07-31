import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/entities/position_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `POST /projects/{project_id}/positions/` 🔒 (api-docs §5.3).
class CreatePositionUseCase {
  final ProjectRepository _repository;

  CreatePositionUseCase(this._repository);

  /// Max simultaneously **open** positions per project (api-docs §5.3). The
  /// server enforces this (`MAX_POSITIONS_PER_PROJECT_LIMIT_EXCEEDED`);
  /// [currentOpenPositionCount] lets the caller fail fast when it already
  /// knows the count (e.g. from `getProjectPositions`).
  static const int maxOpenPositionsPerProject = 5;

  Future<Either<Failure, void>> execute(
    int projectId, {
    required String title,
    required String description,
    String? responsibilities,
    List<String>? requiredSkills,
    PositionLocationType? locationType,
    PositionExpectedLoad? expectedLoad,
    int? currentOpenPositionCount,
  }) {
    final err = validatePositiveId(projectId, 'projectId');
    if (err != null) return Future.value(Left(err));
    if (title.trim().isEmpty) {
      return Future.value(const Left(InputFailure(message: 'Position title is required')));
    }
    if (description.trim().isEmpty) {
      return Future.value(const Left(InputFailure(message: 'Position description is required')));
    }
    if (currentOpenPositionCount != null &&
        currentOpenPositionCount >= maxOpenPositionsPerProject) {
      return Future.value(Left(InputFailure(
        message: 'A project can have at most $maxOpenPositionsPerProject open positions',
      )));
    }
    return _repository.createPosition(
      projectId,
      title: title,
      description: description,
      responsibilities: responsibilities,
      requiredSkills: requiredSkills,
      locationType: locationType,
      expectedLoad: expectedLoad,
    );
  }
}
