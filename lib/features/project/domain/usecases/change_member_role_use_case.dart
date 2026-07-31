import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `POST /projects/{project_id}/members/{user_id}/role/` 🔒 (api-docs §5.2).
class ChangeMemberRoleUseCase {
  final ProjectRepository _repository;

  ChangeMemberRoleUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    int projectId, {
    required int userId,
    required int roleId,
  }) {
    final e1 = validatePositiveId(projectId, 'projectId');
    if (e1 != null) return Future.value(Left(e1));
    final e2 = validatePositiveId(userId, 'userId');
    if (e2 != null) return Future.value(Left(e2));
    final e3 = validatePositiveId(roleId, 'roleId');
    if (e3 != null) return Future.value(Left(e3));
    return _repository.changeMemberRole(projectId, userId: userId, roleId: roleId);
  }
}
