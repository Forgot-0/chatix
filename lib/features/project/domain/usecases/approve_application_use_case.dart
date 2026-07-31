import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `POST /applications/{application_id}/approve/` 🔒 (api-docs §5.4).
/// `409 NOT_PENDING_APPLICATION` if the application was already decided.
class ApproveApplicationUseCase {
  final ProjectRepository _repository;

  ApproveApplicationUseCase(this._repository);

  Future<Either<Failure, void>> execute(String applicationId) {
    final err = validateStringId(applicationId, 'applicationId');
    if (err != null) return Future.value(Left(err));
    return _repository.approveApplication(applicationId);
  }
}
