import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/profile/data/models/avatar_presign_model.dart';
import 'package:chatix/features/profile/data/models/profile_model.dart';

/// Talks to `/profiles/*` (api-docs §4) via [ApiClient], which already maps
/// Dio responses/errors into `Either<Failure, dynamic>`. This layer's only
/// job is building the right request/path and parsing the JSON payload —
/// no business logic, no client-side validation (that's
/// `domain/usecases/*`), no Model→Entity mapping (that's
/// `ProfileRepositoryImpl`).
abstract class ProfileRemoteDataSource {
  /// `GET /profiles/` 🔓 (api-docs §4.2).
  Future<Either<Failure, PageResult<ProfileModel>>> fetchProfiles({
    String? username,
    String? displayName,
    List<String>? skills,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  /// `GET /profiles/{profile_id}/` 🔓 (api-docs §4.3).
  Future<Either<Failure, ProfileModel>> fetchProfile(int profileId);

  /// `PUT /profiles/{profile_id}/` 🔒 (api-docs §4.4). Only the
  /// non-`null` named parameters actually supplied by the caller are put
  /// on the wire — see the ⚠️ on `ProfileRepository.updateProfile` for why
  /// that still means the caller must pass every field it wants kept.
  Future<Either<Failure, void>> updateProfile(
    int profileId, {
    String? specialization,
    String? displayName,
    String? bio,
    List<String>? skills,
    String? dateBirthday,
  });

  /// `POST /profiles/avatar/presign/` 🔒 (api-docs §4.5 step 1).
  Future<Either<Failure, AvatarPresignModel>> presignAvatar({
    required String filename,
    required int size,
    required String contentType,
  });

  /// `POST /profiles/avatar/upload_complete/` 🔒 (api-docs §4.5 step 3).
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

  /// `DELETE /profiles/{profile_id}/{provider}/delete/` 🔒 (api-docs §4.6).
  Future<Either<Failure, void>> removeContact(int profileId, {required String provider});
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final ApiClient _apiClient;

  ProfileRemoteDataSourceImpl(this._apiClient);

  @override
  Future<Either<Failure, PageResult<ProfileModel>>> fetchProfiles({
    String? username,
    String? displayName,
    List<String>? skills,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    // GET /profiles/ is public (api-docs §4.2) — no token is added here on
    // purpose. AuthInterceptor still attaches `Authorization` on top of
    // this if one happens to be stored, since this path isn't in its
    // public-path exclusion list, but the endpoint works identically
    // either way.
    final result = await _apiClient.get(
      '/profiles/',
      queryParameters: {
        if (username != null) 'username': username,
        if (displayName != null) 'display_name': displayName,
        if (skills != null) 'skills': skills,
        'page': page,
        'page_size': pageSize,
        if (sort != null) 'sort': sort,
      },
    );

    return result.map(
      (data) => PageResult<ProfileModel>.fromJson(
        data as Map<String, dynamic>,
        (item) => ProfileModel.fromJson(item as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, ProfileModel>> fetchProfile(int profileId) async {
    final result = await _apiClient.get('/profiles/$profileId/');
    return result.map((data) => ProfileModel.fromJson(data as Map<String, dynamic>));
  }

  @override
  Future<Either<Failure, void>> updateProfile(
    int profileId, {
    String? specialization,
    String? displayName,
    String? bio,
    List<String>? skills,
    String? dateBirthday,
  }) async {
    // api-docs §4.4: this is a real PUT, not a PATCH.
    final result = await _apiClient.put(
      '/profiles/$profileId/',
      data: {
        if (specialization != null) 'specialization': specialization,
        if (displayName != null) 'display_name': displayName,
        if (bio != null) 'bio': bio,
        if (skills != null) 'skills': skills,
        if (dateBirthday != null) 'date_birthday': dateBirthday,
      },
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, AvatarPresignModel>> presignAvatar({
    required String filename,
    required int size,
    required String contentType,
  }) async {
    final result = await _apiClient.post(
      '/profiles/avatar/presign/',
      data: {'filename': filename, 'size': size, 'content_type': contentType},
    );
    return result.map((data) => AvatarPresignModel.fromJson(data as Map<String, dynamic>));
  }

  @override
  Future<Either<Failure, void>> completeAvatarUpload({
    required String keyBase,
    required int size,
    required String contentType,
  }) async {
    final result = await _apiClient.post(
      '/profiles/avatar/upload_complete/',
      data: {'key_base': keyBase, 'size': size, 'content_type': contentType},
    );
    // api-docs §4.5 step 3: response body is the plain string "OK", not
    // JSON — nothing in it is needed, only that the call succeeded.
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> addContact(
    int profileId, {
    required String provider,
    required String contact,
  }) async {
    final result = await _apiClient.post(
      '/profiles/$profileId/contacts/',
      data: {'provider': provider, 'contact': contact},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> removeContact(int profileId, {required String provider}) async {
    // api-docs §4.6 ⚠️: NOT /profiles/{id}/contacts/{provider}/ — the
    // path has no `/contacts/` segment and ends with `/delete/` instead.
    final result = await _apiClient.delete('/profiles/$profileId/$provider/delete/');
    return result.map((_) {});
  }
}

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((ref) {
  return ProfileRemoteDataSourceImpl(ref.watch(apiClientProvider));
});
