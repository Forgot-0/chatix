import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/project/data/models/application_model.dart';
import 'package:chatix/features/project/data/models/position_model.dart';

/// Talks to `/positions/*` and the nested `/projects/{id}/positions/`
/// (api-docs §5.3). Split out from `ProjectRemoteDataSource` for readability;
/// `applyToPosition`/`fetchPositionApplications` live here too because their
/// paths hang off `/positions/{id}/`.
///
/// ⚠️ `GET /positions/` and `GET /positions/{id}/` are **public** (no token
/// required); everything else here is authorized (api-docs §5.3).
abstract class PositionRemoteDataSource {
  Future<Either<Failure, void>> createPosition(
    int projectId, {
    required String title,
    required String description,
    String? responsibilities,
    List<String>? requiredSkills,
    String? locationType,
    String? expectedLoad,
  });

  Future<Either<Failure, PageResult<PositionModel>>> fetchProjectPositions(
    int projectId, {
    String? title,
    List<String>? requiredSkills,
    bool isOpen = true,
    String? locationType,
    String? expectedLoad,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  Future<Either<Failure, PageResult<PositionModel>>> fetchPositions({
    int? projectId,
    String? title,
    List<String>? requiredSkills,
    bool isOpen = true,
    String? locationType,
    String? expectedLoad,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  Future<Either<Failure, PositionModel>> fetchPosition(String positionId);

  Future<Either<Failure, void>> updatePosition(
    String positionId, {
    String? title,
    String? description,
    String? responsibilities,
    List<String>? requiredSkills,
    String? locationType,
    String? expectedLoad,
  });

  Future<Either<Failure, void>> deletePosition(String positionId);

  Future<Either<Failure, PageResult<ApplicationModel>>> fetchPositionApplications(
    String positionId, {
    int? projectId,
    int? candidateId,
    String? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  Future<Either<Failure, void>> applyToPosition(
    String positionId, {
    String? message,
  });
}

class PositionRemoteDataSourceImpl implements PositionRemoteDataSource {
  final ApiClient _apiClient;

  PositionRemoteDataSourceImpl(this._apiClient);

  @override
  Future<Either<Failure, void>> createPosition(
    int projectId, {
    required String title,
    required String description,
    String? responsibilities,
    List<String>? requiredSkills,
    String? locationType,
    String? expectedLoad,
  }) async {
    final result = await _apiClient.post(
      '/projects/$projectId/positions/',
      data: {
        'title': title,
        'description': description,
        'responsibilities': ?responsibilities,
        'required_skills': ?requiredSkills,
        'location_type': ?locationType,
        'expected_load': ?expectedLoad,
      },
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, PageResult<PositionModel>>> fetchProjectPositions(
    int projectId, {
    String? title,
    List<String>? requiredSkills,
    bool isOpen = true,
    String? locationType,
    String? expectedLoad,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _apiClient.get(
      '/projects/$projectId/positions/',
      queryParameters: {
        'title': ?title,
        'required_skills': ?requiredSkills,
        'is_open': isOpen,
        'location_type': ?locationType,
        'expected_load': ?expectedLoad,
        'page': page,
        'page_size': pageSize,
        'sort': ?sort,
      },
    );
    return result.map(
      (data) => PageResult<PositionModel>.fromJson(
        data as Map<String, dynamic>,
        (item) => PositionModel.fromJson(item as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, PageResult<PositionModel>>> fetchPositions({
    int? projectId,
    String? title,
    List<String>? requiredSkills,
    bool isOpen = true,
    String? locationType,
    String? expectedLoad,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    // Public list (api-docs §5.3) — no token added on purpose.
    final result = await _apiClient.get(
      '/positions/',
      queryParameters: {
        'project_id': ?projectId,
        'title': ?title,
        'required_skills': ?requiredSkills,
        'is_open': isOpen,
        'location_type': ?locationType,
        'expected_load': ?expectedLoad,
        'page': page,
        'page_size': pageSize,
        'sort': ?sort,
      },
    );
    return result.map(
      (data) => PageResult<PositionModel>.fromJson(
        data as Map<String, dynamic>,
        (item) => PositionModel.fromJson(item as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, PositionModel>> fetchPosition(String positionId) async {
    // Public detail (api-docs §5.3).
    final result = await _apiClient.get('/positions/$positionId/');
    return result.map((data) => PositionModel.fromJson(data as Map<String, dynamic>));
  }

  @override
  Future<Either<Failure, void>> updatePosition(
    String positionId, {
    String? title,
    String? description,
    String? responsibilities,
    List<String>? requiredSkills,
    String? locationType,
    String? expectedLoad,
  }) async {
    final result = await _apiClient.put(
      '/positions/$positionId/',
      data: {
        'title': ?title,
        'description': ?description,
        'responsibilities': ?responsibilities,
        'required_skills': ?requiredSkills,
        'location_type': ?locationType,
        'expected_load': ?expectedLoad,
      },
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> deletePosition(String positionId) async {
    final result = await _apiClient.delete('/positions/$positionId/');
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, PageResult<ApplicationModel>>> fetchPositionApplications(
    String positionId, {
    int? projectId,
    int? candidateId,
    String? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _apiClient.get(
      '/positions/$positionId/applications/',
      queryParameters: {
        'project_id': ?projectId,
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
  Future<Either<Failure, void>> applyToPosition(
    String positionId, {
    String? message,
  }) async {
    final result = await _apiClient.post(
      '/positions/$positionId/applications/',
      data: {'message': ?message},
    );
    return result.map((_) {});
  }
}

final positionRemoteDataSourceProvider = Provider<PositionRemoteDataSource>((ref) {
  return PositionRemoteDataSourceImpl(ref.watch(apiClientProvider));
});
