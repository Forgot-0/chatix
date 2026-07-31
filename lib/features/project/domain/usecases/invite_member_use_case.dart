import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `POST /projects/{project_id}/invite/` 🔒, requires `member:invite`
/// (api-docs §5.2). [roleId] is mandatory — the backend does not auto-assign
/// a default project role (api-docs §9.2).
class InviteMemberUseCase {
  final ProjectRepository _repository;

  InviteMemberUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    int projectId, {
    required int userId,
    required int roleId,
    Map<String, bool>? permissionsOverrides,
  }) {
    final e1 = validatePositiveId(projectId, 'projectId');
    if (e1 != null) return Future.value(Left(e1));
    final e2 = validatePositiveId(userId, 'userId');
    if (e2 != null) return Future.value(Left(e2));
    final e3 = validatePositiveId(roleId, 'roleId');
    if (e3 != null) return Future.value(Left(e3));
    return _repository.inviteMember(
      projectId,
      userId: userId,
      roleId: roleId,
      permissionsOverrides: permissionsOverrides,
    );
  }
}
