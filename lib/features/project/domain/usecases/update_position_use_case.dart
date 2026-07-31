import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/entities/position_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `PUT /positions/{position_id}/` 🔒 (api-docs §5.3).
class UpdatePositionUseCase {
  final ProjectRepository _repository;

  UpdatePositionUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String positionId, {
    String? title,
    String? description,
    String? responsibilities,
    List<String>? requiredSkills,
    PositionLocationType? locationType,
    PositionExpectedLoad? expectedLoad,
  }) {
    final err = validateStringId(positionId, 'positionId');
    if (err != null) return Future.value(Left(err));
    if (title != null && title.trim().isEmpty) {
      return Future.value(const Left(InputFailure(message: 'Position title cannot be empty')));
    }
    return _repository.updatePosition(
      positionId,
      title: title,
      description: description,
      responsibilities: responsibilities,
      requiredSkills: requiredSkills,
      locationType: locationType,
      expectedLoad: expectedLoad,
    );
  }
}
