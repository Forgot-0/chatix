import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `POST /positions/{position_id}/applications/` 🔒 — apply to a position with
/// an optional [message] (api-docs §5.3).
class ApplyToPositionUseCase {
  final ProjectRepository _repository;

  ApplyToPositionUseCase(this._repository);

  Future<Either<Failure, void>> execute(String positionId, {String? message}) {
    final err = validateStringId(positionId, 'positionId');
    if (err != null) return Future.value(Left(err));
    return _repository.applyToPosition(positionId, message: message);
  }
}
