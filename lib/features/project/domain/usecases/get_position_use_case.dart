import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/entities/position_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `GET /positions/{position_id}/` 🔓 public (api-docs §5.3).
class GetPositionUseCase {
  final ProjectRepository _repository;

  GetPositionUseCase(this._repository);

  Future<Either<Failure, PositionEntity>> execute(String positionId) {
    final err = validateStringId(positionId, 'positionId');
    if (err != null) return Future.value(Left(err));
    return _repository.getPosition(positionId);
  }
}
