import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/profile_photo.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// A person's whole photo history, current first (api-docs §4.5.1).
///
/// One request: a profile keeps at most [maxPhotos] pictures and a page
/// takes as many, so there is never a second page to ask for.
class GetProfilePhotosUseCase {
  /// `MAX_PROFILE_PHOTOS` on the server, and the largest `page_size`.
  static const int maxPhotos = 100;

  final ProfileRepository _repository;

  GetProfilePhotosUseCase(this._repository);

  Future<Either<Failure, List<ProfilePhoto>>> execute(int profileId) async {
    if (profileId <= 0) {
      return const Left(
        InputFailure(message: 'profileId must be a positive number'),
      );
    }

    final result = await _repository.getPhotos(profileId, pageSize: maxPhotos);
    return result.map((page) => page.items);
  }
}
