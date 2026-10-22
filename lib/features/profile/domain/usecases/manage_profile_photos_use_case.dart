import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// The two things one can do to one's own old photos: bring one back to
/// the front, or throw one away (api-docs §4.5.1).
///
/// Only one's own — someone else's photo id is a `404
/// NOT_FOUND_PROFILE_PHOTO` from the server, not something checked here.
class ManageProfilePhotosUseCase {
  final ProfileRepository _repository;

  ManageProfilePhotosUseCase(this._repository);

  Future<Either<Failure, void>> makeMain(String photoId) {
    if (photoId.trim().isEmpty) return Future.value(_noId);
    return _repository.setMainPhoto(photoId);
  }

  Future<Either<Failure, void>> delete(String photoId) {
    if (photoId.trim().isEmpty) return Future.value(_noId);
    return _repository.deletePhoto(photoId);
  }

  static const Either<Failure, void> _noId = Left(
    InputFailure(message: 'photoId cannot be empty'),
  );
}
