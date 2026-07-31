import 'package:chatix/features/profile/data/models/avatar_presign_model.dart';
import 'package:chatix/features/profile/data/models/profile_model.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:chatix/features/profile/domain/entities/avatar_presign_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// Talks to [ProfileRemoteDataSource] and turns its `Either<Failure,
/// Model>` into `Either<Failure, Entity>`. No local persistence or
/// orchestration is needed here (unlike `AuthRepositoryImpl`) — every
/// profile call is a straight passthrough plus the model→entity mapping.
class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;

  ProfileRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, PageResult<ProfileEntity>>> getProfiles({
    String? username,
    String? displayName,
    List<String>? skills,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _remoteDataSource.fetchProfiles(
      username: username,
      displayName: displayName,
      skills: skills,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
    return result.map((page) => page.map((model) => model.toEntity()));
  }

  @override
  Future<Either<Failure, ProfileEntity>> getProfile(int profileId) async {
    final result = await _remoteDataSource.fetchProfile(profileId);
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, void>> updateProfile(
    int profileId, {
    String? specialization,
    String? displayName,
    String? bio,
    List<String>? skills,
    DateTime? dateBirthday,
  }) {
    return _remoteDataSource.updateProfile(
      profileId,
      specialization: specialization,
      displayName: displayName,
      bio: bio,
      skills: skills,
      // api-docs §1.9/§4.3: date_birthday is date-only on the wire.
      dateBirthday: dateBirthday != null ? _formatDate(dateBirthday) : null,
    );
  }

  @override
  Future<Either<Failure, AvatarPresignEntity>> presignAvatar({
    required String filename,
    required int size,
    required String contentType,
  }) async {
    final result = await _remoteDataSource.presignAvatar(
      filename: filename,
      size: size,
      contentType: contentType,
    );
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, void>> completeAvatarUpload({
    required String keyBase,
    required int size,
    required String contentType,
  }) {
    return _remoteDataSource.completeAvatarUpload(
      keyBase: keyBase,
      size: size,
      contentType: contentType,
    );
  }

  @override
  Future<Either<Failure, void>> addContact(
    int profileId, {
    required String provider,
    required String contact,
  }) {
    return _remoteDataSource.addContact(profileId, provider: provider, contact: contact);
  }

  @override
  Future<Either<Failure, void>> removeContact(int profileId, {required String provider}) {
    return _remoteDataSource.removeContact(profileId, provider: provider);
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(profileRemoteDataSourceProvider));
});
