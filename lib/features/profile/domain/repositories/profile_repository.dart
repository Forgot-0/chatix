import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/profile/domain/entities/avatar_presign_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';

/// `/profiles/*` (api-docs §4). Every write endpoint here requires
/// ownership of the profile (`profile_id == current user_id`) or the
/// combined `profile:update` + `user:update` system rights (api-docs §4.4,
/// §4.6) — there's no client UI for the rights case yet, see
/// `ProfileScreen`'s `canEdit` check.
abstract class ProfileRepository {
  /// `GET /profiles/` 🔓 (api-docs §4.2). [page] is 1-based; [pageSize] is
  /// capped at 100 server-side.
  Future<Either<Failure, PageResult<ProfileEntity>>> getProfiles({
    String? username,
    String? displayName,
    List<String>? skills,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  /// `GET /profiles/{profile_id}/` 🔓 (api-docs §4.3). `Left(ApiFailure(code:
  /// 'NOT_FOUND_PROFILE'))` on 404.
  Future<Either<Failure, ProfileEntity>> getProfile(int profileId);

  /// `PUT /profiles/{profile_id}/` 🔒 (api-docs §4.4) — note this is a real
  /// `PUT`, not a `PATCH`. All parameters are optional on the wire, but the
  /// backend applies whatever it receives *including explicit `null`s*, so
  /// omitting a field here is only safe if you genuinely want the server
  /// default for it. Callers that mean "change just this one field" (e.g.
  /// `ProfileEditScreen`) must pass the full current value for every other
  /// field too, not just the one being changed.
  Future<Either<Failure, void>> updateProfile(
    int profileId, {
    String? specialization,
    String? displayName,
    String? bio,
    List<String>? skills,
    DateTime? dateBirthday,
  });

  /// Step 1 of the avatar upload flow: `POST /profiles/avatar/presign/` 🔒
  /// (api-docs §4.5, rate-limited 4/5min). Always targets the *caller's
  /// own* profile — there's no `profileId` parameter because the backend
  /// derives it from the JWT.
  Future<Either<Failure, AvatarPresignEntity>> presignAvatar({
    required String filename,
    required int size,
    required String contentType,
  });

  /// Step 3 of the avatar upload flow: `POST
  /// /profiles/avatar/upload_complete/` 🔒 (api-docs §4.5). Must be called
  /// with the `keyBase` from the matching `presignAvatar` response, after
  /// step 2 (the raw upload to the presigned URL, see `AvatarUploader`) has
  /// already succeeded.
  Future<Either<Failure, void>> completeAvatarUpload({
    required String keyBase,
    required int size,
    required String contentType,
  });

  /// `POST /profiles/{profile_id}/contacts/` 🔒 (api-docs §4.6).
  Future<Either<Failure, void>> addContact(
    int profileId, {
    required String provider,
    required String contact,
  });

  /// `DELETE /profiles/{profile_id}/{provider}/delete/` 🔒 (api-docs §4.6)
  /// — note the unusual path shape: no `/contacts/` segment, `/delete/`
  /// suffix instead.
  Future<Either<Failure, void>> removeContact(
    int profileId, {
    required String provider,
  });
}
