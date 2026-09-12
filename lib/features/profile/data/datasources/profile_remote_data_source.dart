import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/profile/data/models/avatar_presign_model.dart';
import 'package:chatix/features/profile/data/models/profile_model.dart';
import 'package:chatix/core/network/request_cancellation.dart';

abstract class ProfileRemoteDataSource {
  Future<Either<Failure, PageResult<ProfileModel>>> fetchProfiles({
    String? username,
    String? displayName,
    List<String>? skills,
    int page = 1,
    int pageSize = 20,
    String? sort,
    RequestCancellation? cancellation,
  });

  Future<Either<Failure, ProfileModel>> fetchProfile(int profileId);

  Future<Either<Failure, void>> updateProfile(
    int profileId, {
    String? specialization,
    String? displayName,
    String? bio,
    List<String>? skills,
    String? dateBirthday,
  });

  Future<Either<Failure, AvatarPresignModel>> presignAvatar({
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
    RequestCancellation? cancellation,
  }) async {
    final result = await _apiClient.get(
      '/profiles/',
      cancelToken: cancellation?.dioToken,
      queryParameters: {
        'username': ?username,
        'display_name': ?displayName,
        'skills': ?skills,
        'page': page,
        'page_size': pageSize,
        'sort': ?sort,
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
    return result.map(
      (data) => ProfileModel.fromJson(data as Map<String, dynamic>),
    );
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
    final result = await _apiClient.put(
      '/profiles/$profileId/',
      data: {
        'specialization': ?specialization,
        'display_name': ?displayName,
        'bio': ?bio,
        'skills': ?skills,
        'date_birthday': ?dateBirthday,
      },
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, AvatarPresignModel>> presignAvatar({
    required String filename,
  }) async {
    final result = await _apiClient.post(
      '/profiles/avatar/presign/',
      data: {'filename': filename},
    );
    return result.map(
      (data) => AvatarPresignModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Either<Failure, void>> completeAvatarUpload({
    required String fileKey,
  }) async {
    final result = await _apiClient.post(
      '/profiles/avatar/upload_complete/',
      data: {'file_key': fileKey},
    );
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
  Future<Either<Failure, void>> removeContact(
    int profileId, {
    required String provider,
  }) async {
    final result = await _apiClient.delete(
      '/profiles/$profileId/$provider/delete/',
    );
    return result.map((_) {});
  }
}

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  return ProfileRemoteDataSourceImpl(ref.watch(apiClientProvider));
});
