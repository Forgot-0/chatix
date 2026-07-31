import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `DELETE /positions/{position_id}/` 🔒 (api-docs §5.3).
class DeletePositionUseCase {
  final ProjectRepository _repository;

  DeletePositionUseCase(this._repository);

  Future<Either<Failure, void>> execute(String positionId) {
    final err = validateStringId(positionId, 'positionId');
    if (err != null) return Future.value(Left(err));
    return _repository.deletePosition(positionId);
  }
}
