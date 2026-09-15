import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/profile/domain/entities/avatar_presign_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/core/network/request_cancellation.dart';

abstract class ProfileRepository {
  Future<Either<Failure, PageResult<ProfileEntity>>> getProfiles({
    /// One field to search both `username` and `display_name`. Cannot be
    /// combined with either of them.
    String? q,
    String? username,
    String? displayName,
    List<String>? skills,
    int page = 1,
    int pageSize = 20,
    String? sort,
    RequestCancellation? cancellation,
  });

  Future<Either<Failure, ProfileEntity>> getProfile(int profileId);

  /// The caller's own profile, created on the spot if it is not there yet.
  Future<Either<Failure, ProfileEntity>> getMyProfile();

  Future<Either<Failure, void>> updateProfile(
    int profileId, {
    String? specialization,
    String? displayName,
    String? bio,
    List<String>? skills,
    DateTime? dateBirthday,
  });

  Future<Either<Failure, AvatarPresignEntity>> presignAvatar({
    required String filename,
  });

  Future<Either<Failure, void>> completeAvatarUpload({required String fileKey});

  Future<Either<Failure, void>> addContact(
    int profileId, {
    required String provider,
    required String contact,
  });

  Future<Either<Failure, void>> removeContact(
    int profileId, {
    required String provider,
  });
}
