import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/core/network/request_cancellation.dart';

class GetProfilesUseCase {
  /// `q` shorter than this is a `422`, not an empty page (api-docs §4.2).
  static const int minQueryLength = 2;

  static const int maxQueryLength = 150;

  final ProfileRepository _repository;

  GetProfilesUseCase(this._repository);

  Future<Either<Failure, PageResult<ProfileEntity>>> execute({
    String? q,
    String? username,
    String? displayName,
    List<String>? skills,
    int page = 1,
    int pageSize = 20,
    String? sort,
    RequestCancellation? cancellation,
  }) {
    if (page < 1) {
      return Future.value(
        const Left(InputFailure(message: 'Page must be 1 or greater')),
      );
    }

    if (pageSize < 1 || pageSize > 100) {
      return Future.value(
        const Left(
          InputFailure(message: 'Page size must be between 1 and 100'),
        ),
      );
    }

    final needle = q?.trim();
    if (needle != null) {
      if (username != null || displayName != null) {
        // The server answers 422 rather than picking one, so there is
        // nothing to gain by finding out the hard way.
        return Future.value(
          const Left(
            InputFailure(
              message: 'Search by one field or by name and username, not both',
            ),
          ),
        );
      }
      if (needle.length < minQueryLength) {
        return Future.value(
          Left(
            InputFailure(
              message: 'Type at least $minQueryLength characters to search',
            ),
          ),
        );
      }
      if (needle.length > maxQueryLength) {
        return Future.value(
          Left(
            InputFailure(
              message: 'A search can be at most $maxQueryLength characters',
            ),
          ),
        );
      }
    }

    return _repository.getProfiles(
      q: needle,
      username: username,
      displayName: displayName,
      skills: skills,
      page: page,
      pageSize: pageSize,
      sort: sort,
      cancellation: cancellation,
    );
  }
}
