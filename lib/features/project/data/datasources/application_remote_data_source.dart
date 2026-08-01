import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/project/data/models/application_model.dart';

/// Talks to `/applications/*` (api-docs §5.4). Note that *creating* an
/// application (applying to a position) is not here — it hangs off
/// `/positions/{id}/applications/` and lives in `PositionRemoteDataSource`.
/// This datasource covers listing and the approve/reject decisions.
abstract class ApplicationRemoteDataSource {
  Future<Either<Failure, PageResult<ApplicationModel>>> fetchApplications({
    int? projectId,
    String? positionId,
    int? candidateId,
    String? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  Future<Either<Failure, PageResult<ApplicationModel>>> fetchMyApplications({
    String? positionId,
    int? projectId,
    String? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  Future<Either<Failure, void>> approveApplication(String applicationId);

  Future<Either<Failure, void>> rejectApplication(String applicationId);
}

class ApplicationRemoteDataSourceImpl implements ApplicationRemoteDataSource {
  final ApiClient _apiClient;

  ApplicationRemoteDataSourceImpl(this._apiClient);

  @override
  Future<Either<Failure, PageResult<ApplicationModel>>> fetchApplications({
    int? projectId,
    String? positionId,
    int? candidateId,
    String? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _apiClient.get(
      '/applications/',
      queryParameters: {
        'project_id': ?projectId,
        'position_id': ?positionId,
        'candidate_id': ?candidateId,
        'status': ?status,
        'page': page,
        'page_size': pageSize,
        'sort': ?sort,
      },
    );
    return result.map(
      (data) => PageResult<ApplicationModel>.fromJson(
        data as Map<String, dynamic>,
        (item) => ApplicationModel.fromJson(item as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, PageResult<ApplicationModel>>> fetchMyApplications({
    String? positionId,
    int? projectId,
    String? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _apiClient.get(
      '/applications/me/',
      queryParameters: {
        'position_id': ?positionId,
        'project_id': ?projectId,
        'status': ?status,
        'page': page,
        'page_size': pageSize,
        'sort': ?sort,
      },
    );
    return result.map(
      (data) => PageResult<ApplicationModel>.fromJson(
        data as Map<String, dynamic>,
        (item) => ApplicationModel.fromJson(item as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> approveApplication(String applicationId) async {
    final result = await _apiClient.post('/applications/$applicationId/approve/');
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> rejectApplication(String applicationId) async {
    final result = await _apiClient.post('/applications/$applicationId/reject/');
    return result.map((_) {});
  }
}

final applicationRemoteDataSourceProvider = Provider<ApplicationRemoteDataSource>((ref) {
  return ApplicationRemoteDataSourceImpl(ref.watch(apiClientProvider));
});
