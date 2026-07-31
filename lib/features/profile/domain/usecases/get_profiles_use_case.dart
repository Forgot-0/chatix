import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// `GET /profiles/` 🔓 (api-docs §4.2).
class GetProfilesUseCase {
  final ProfileRepository _repository;

  GetProfilesUseCase(this._repository);

  Future<Either<Failure, PageResult<ProfileEntity>>> execute({
    String? username,
    String? displayName,
    List<String>? skills,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) {
    if (page < 1) {
      return Future.value(
        const Left(InputFailure(message: 'Page must be 1 or greater')),
      );
    }

    // api-docs §1.5: page_size is `ge=1, le=100` server-side — checked
    // here too so an obviously-bad value fails fast with a clear message
    // instead of a generic 400 from the server.
    if (pageSize < 1 || pageSize > 100) {
      return Future.value(
        const Left(InputFailure(message: 'Page size must be between 1 and 100')),
      );
    }

    return _repository.getProfiles(
      username: username,
      displayName: displayName,
      skills: skills,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
  }
}
