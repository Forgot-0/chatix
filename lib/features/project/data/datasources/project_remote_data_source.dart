import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/project/data/models/project_member_model.dart';
import 'package:chatix/features/project/data/models/project_model.dart';
import 'package:chatix/features/project/data/models/project_role_model.dart';

/// Talks to `/projects/*`, `/profiles/invites/my/` and `/project_roles/`
/// (api-docs §5.1, §5.2, §5.5) via [ApiClient]. Positions and applications
/// live in their own datasources (`PositionRemoteDataSource`,
/// `ApplicationRemoteDataSource`) even though they share this repository —
/// the domains are coupled but the endpoints split cleanly by resource.
///
/// This layer only builds paths/requests and parses JSON — no validation
/// (that's `domain/usecases`) and no model→entity mapping (that's
/// `ProjectRepositoryImpl`).
abstract class ProjectRemoteDataSource {
  Future<Either<Failure, void>> createProject({
    required String name,
    required String slug,
    String? smallDescription,
    String? description,
    String? visibility,
    Map<String, dynamic>? metaData,
    List<String>? tags,
  });

  Future<Either<Failure, PageResult<ProjectModel>>> fetchProjects({
    String? name,
    String? slug,
    List<String>? tags,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });

  Future<Either<Failure, PageResult<ProjectModel>>> fetchMyProjects({
    int page = 1,
    int pageSize = 20,
  });

  Future<Either<Failure, ProjectModel>> fetchProject(int projectId);

  Future<Either<Failure, void>> updateProject(
    int projectId, {
    String? name,
    String? description,
    String? visibility,
    Map<String, dynamic>? metaData,
    List<String>? tags,
  });

  Future<Either<Failure, void>> deleteProject(int projectId);

  Future<Either<Failure, void>> inviteMember(
    int projectId, {
    required int userId,
    required int roleId,
    Map<String, bool>? permissionsOverrides,
  });

  Future<Either<Failure, void>> acceptInvite(int projectId);

  Future<Either<Failure, PageResult<ProjectMemberModel>>> fetchMyInvites({
    int page = 1,
    int pageSize = 20,
  });

  Future<Either<Failure, void>> changeMemberRole(
    int projectId, {
    required int userId,
    required int roleId,
  });

  Future<Either<Failure, void>> updateMemberPermissions(
    int projectId, {
    required int userId,
    required Map<String, bool> permissionsOverrides,
  });

  Future<Either<Failure, PageResult<ProjectRoleModel>>> fetchProjectRoles({
    String? name,
    int page = 1,
    int pageSize = 20,
    String? sort,
  });
}

class ProjectRemoteDataSourceImpl implements ProjectRemoteDataSource {
  final ApiClient _apiClient;

  ProjectRemoteDataSourceImpl(this._apiClient);

  @override
  Future<Either<Failure, void>> createProject({
    required String name,
    required String slug,
    String? smallDescription,
    String? description,
    String? visibility,
    Map<String, dynamic>? metaData,
    List<String>? tags,
  }) async {
    final result = await _apiClient.post(
      '/projects/',
      // ⚠️ api-docs §5.1: the long text field is sent as `description` on
      // create/update, even though the response returns it as
      // `full_description`. Do NOT send `full_description` here.
      data: {
        'name': name,
        'slug': slug,
        'small_description': ?smallDescription,
        'description': ?description,
        'visibility': ?visibility,
        'meta_data': ?metaData,
        'tags': ?tags,
      },
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, PageResult<ProjectModel>>> fetchProjects({
    String? name,
    String? slug,
    List<String>? tags,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _apiClient.get(
      '/projects/',
      queryParameters: {
        'name': ?name,
        'slug': ?slug,
        'tags': ?tags,
        'page': page,
        'page_size': pageSize,
        'sort': ?sort,
      },
    );
    return result.map(
      (data) => PageResult<ProjectModel>.fromJson(
        data as Map<String, dynamic>,
        (item) => ProjectModel.fromJson(item as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, PageResult<ProjectModel>>> fetchMyProjects({
    int page = 1,
    int pageSize = 20,
  }) async {
    final result = await _apiClient.get(
      '/projects/my/',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    return result.map(
      (data) => PageResult<ProjectModel>.fromJson(
        data as Map<String, dynamic>,
        (item) => ProjectModel.fromJson(item as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, ProjectModel>> fetchProject(int projectId) async {
    final result = await _apiClient.get('/projects/$projectId/');
    return result.map((data) => ProjectModel.fromJson(data as Map<String, dynamic>));
  }

  @override
  Future<Either<Failure, void>> updateProject(
    int projectId, {
    String? name,
    String? description,
    String? visibility,
    Map<String, dynamic>? metaData,
    List<String>? tags,
  }) async {
    // ⚠️ api-docs §5.1: `PUT` (not PATCH), no `slug`/`small_description`, and
    // the long text is `description` (same wire-name asymmetry as create).
    final result = await _apiClient.put(
      '/projects/$projectId/',
      data: {
        'name': ?name,
        'description': ?description,
        'visibility': ?visibility,
        'meta_data': ?metaData,
        'tags': ?tags,
      },
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> deleteProject(int projectId) async {
    final result = await _apiClient.delete('/projects/$projectId/');
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> inviteMember(
    int projectId, {
    required int userId,
    required int roleId,
    Map<String, bool>? permissionsOverrides,
  }) async {
    final result = await _apiClient.post(
      '/projects/$projectId/invite/',
      data: {
        'user_id': userId,
        'role_id': roleId,
        'permissions_overrides': ?permissionsOverrides,
      },
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> acceptInvite(int projectId) async {
    final result = await _apiClient.post('/projects/$projectId/members/accept/');
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, PageResult<ProjectMemberModel>>> fetchMyInvites({
    int page = 1,
    int pageSize = 20,
  }) async {
    // ⚠️ api-docs §5.2: this list physically lives under `/profiles`, NOT
    // `/projects` — a real backend routing quirk (the router is mounted with
    // `prefix="/profiles"`). Kept verbatim because that's what the server
    // actually serves.
    final result = await _apiClient.get(
      '/profiles/invites/my/',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    return result.map(
      (data) => PageResult<ProjectMemberModel>.fromJson(
        data as Map<String, dynamic>,
        (item) => ProjectMemberModel.fromJson(item as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> changeMemberRole(
    int projectId, {
    required int userId,
    required int roleId,
  }) async {
    final result = await _apiClient.post(
      '/projects/$projectId/members/$userId/role/',
      data: {'role_id': roleId},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> updateMemberPermissions(
    int projectId, {
    required int userId,
    required Map<String, bool> permissionsOverrides,
  }) async {
    final result = await _apiClient.put(
      '/projects/$projectId/members/$userId/permissions/',
      data: {'permissions_overrides': permissionsOverrides},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, PageResult<ProjectRoleModel>>> fetchProjectRoles({
    String? name,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    // GET /project_roles/ is public + read-only (api-docs §5.5).
    final result = await _apiClient.get(
      '/project_roles/',
      queryParameters: {
        'name': ?name,
        'page': page,
        'page_size': pageSize,
        'sort': ?sort,
      },
    );
    return result.map(
      (data) => PageResult<ProjectRoleModel>.fromJson(
        data as Map<String, dynamic>,
        (item) => ProjectRoleModel.fromJson(item as Map<String, dynamic>),
      ),
    );
  }
}

final projectRemoteDataSourceProvider = Provider<ProjectRemoteDataSource>((ref) {
  return ProjectRemoteDataSourceImpl(ref.watch(apiClientProvider));
});
