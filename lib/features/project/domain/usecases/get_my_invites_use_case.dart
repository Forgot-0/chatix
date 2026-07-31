import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/project/domain/entities/project_member_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `GET /profiles/invites/my/` 🔒 (api-docs §5.2). ⚠️ Served under `/profiles`,
/// not `/projects` — see the repository/datasource note.
class GetMyInvitesUseCase {
  final ProjectRepository _repository;

  GetMyInvitesUseCase(this._repository);

  Future<Either<Failure, PageResult<ProjectMemberEntity>>> execute({
    int page = 1,
    int pageSize = 20,
  }) {
    final err = validatePaging(page, pageSize);
    if (err != null) return Future.value(Left(err));
    return _repository.getMyInvites(page: page, pageSize: pageSize);
  }
}
