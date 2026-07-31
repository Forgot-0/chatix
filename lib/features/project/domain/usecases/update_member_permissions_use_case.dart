import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `PUT /projects/{project_id}/members/{user_id}/permissions/` 🔒
/// (api-docs §5.2). Replaces the member's permission overrides wholesale.
class UpdateMemberPermissionsUseCase {
  final ProjectRepository _repository;

  UpdateMemberPermissionsUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    int projectId, {
    required int userId,
    required Map<String, bool> permissionsOverrides,
  }) {
    final e1 = validatePositiveId(projectId, 'projectId');
    if (e1 != null) return Future.value(Left(e1));
    final e2 = validatePositiveId(userId, 'userId');
    if (e2 != null) return Future.value(Left(e2));
    return _repository.updateMemberPermissions(
      projectId,
      userId: userId,
      permissionsOverrides: permissionsOverrides,
    );
  }
}
