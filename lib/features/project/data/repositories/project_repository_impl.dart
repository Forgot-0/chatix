import 'package:chatix/features/project/data/models/application_model.dart';
import 'package:chatix/features/project/data/models/position_model.dart';
import 'package:chatix/features/project/data/models/project_member_model.dart';
import 'package:chatix/features/project/data/models/project_model.dart';
import 'package:chatix/features/project/data/models/project_role_model.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/project/data/datasources/application_remote_data_source.dart';
import 'package:chatix/features/project/data/datasources/position_remote_data_source.dart';
import 'package:chatix/features/project/data/datasources/project_remote_data_source.dart';
import 'package:chatix/features/project/domain/entities/application_entity.dart';
import 'package:chatix/features/project/domain/entities/position_entity.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/domain/entities/project_member_entity.dart';
import 'package:chatix/features/project/domain/entities/project_role_entity.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// Fans out across the three datasources (`project`/`position`/`application`)
/// and maps every `Either<Failure, Model>` to `Either<Failure, Entity>`. All
/// enum→wire-string conversions happen here (via each enum's `.wire`) so the
/// datasources stay string-only and the domain stays enum-only.
class ProjectRepositoryImpl implements ProjectRepository {
  final ProjectRemoteDataSource _projectDataSource;
  final PositionRemoteDataSource _positionDataSource;
  final ApplicationRemoteDataSource _applicationDataSource;

  ProjectRepositoryImpl(
    this._projectDataSource,
    this._positionDataSource,
    this._applicationDataSource,
  );

  // --- Projects --------------------------------------------------------------

  @override
  Future<Either<Failure, void>> createProject({
    required String name,
    required String slug,
    String? smallDescription,
    String? description,
    ProjectVisibility? visibility,
    Map<String, dynamic>? metaData,
    List<String>? tags,
  }) {
    return _projectDataSource.createProject(
      name: name,
      slug: slug,
      smallDescription: smallDescription,
      description: description,
      visibility: visibility?.wire,
      metaData: metaData,
      tags: tags,
    );
  }

  @override
  Future<Either<Failure, PageResult<ProjectEntity>>> getProjects({
    String? name,
    String? slug,
    List<String>? tags,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _projectDataSource.fetchProjects(
      name: name,
      slug: slug,
      tags: tags,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
    return result.map((page) => page.map((model) => model.toEntity()));
  }

  @override
  Future<Either<Failure, PageResult<ProjectEntity>>> getMyProjects({
    int page = 1,
    int pageSize = 20,
  }) async {
    final result = await _projectDataSource.fetchMyProjects(page: page, pageSize: pageSize);
    return result.map((page) => page.map((model) => model.toEntity()));
  }

  @override
  Future<Either<Failure, ProjectEntity>> getProject(int projectId) async {
    final result = await _projectDataSource.fetchProject(projectId);
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, void>> updateProject(
    int projectId, {
    String? name,
    String? description,
    ProjectVisibility? visibility,
    Map<String, dynamic>? metaData,
    List<String>? tags,
  }) {
    return _projectDataSource.updateProject(
      projectId,
      name: name,
      description: description,
      visibility: visibility?.wire,
      metaData: metaData,
      tags: tags,
    );
  }

  @override
  Future<Either<Failure, void>> deleteProject(int projectId) {
    return _projectDataSource.deleteProject(projectId);
  }

  // --- Members & invites -----------------------------------------------------

  @override
  Future<Either<Failure, void>> inviteMember(
    int projectId, {
    required int userId,
    required int roleId,
    Map<String, bool>? permissionsOverrides,
  }) {
    return _projectDataSource.inviteMember(
      projectId,
      userId: userId,
      roleId: roleId,
      permissionsOverrides: permissionsOverrides,
    );
  }

  @override
  Future<Either<Failure, void>> acceptInvite(int projectId) {
    return _projectDataSource.acceptInvite(projectId);
  }

  @override
  Future<Either<Failure, PageResult<ProjectMemberEntity>>> getMyInvites({
    int page = 1,
    int pageSize = 20,
  }) async {
    final result = await _projectDataSource.fetchMyInvites(page: page, pageSize: pageSize);
    return result.map((page) => page.map((model) => model.toEntity()));
  }

  @override
  Future<Either<Failure, void>> changeMemberRole(
    int projectId, {
    required int userId,
    required int roleId,
  }) {
    return _projectDataSource.changeMemberRole(projectId, userId: userId, roleId: roleId);
  }

  @override
  Future<Either<Failure, void>> updateMemberPermissions(
    int projectId, {
    required int userId,
    required Map<String, bool> permissionsOverrides,
  }) {
    return _projectDataSource.updateMemberPermissions(
      projectId,
      userId: userId,
      permissionsOverrides: permissionsOverrides,
    );
  }

  // --- Positions -------------------------------------------------------------

  @override
  Future<Either<Failure, void>> createPosition(
    int projectId, {
    required String title,
    required String description,
    String? responsibilities,
    List<String>? requiredSkills,
    PositionLocationType? locationType,
    PositionExpectedLoad? expectedLoad,
  }) {
    return _positionDataSource.createPosition(
      projectId,
      title: title,
      description: description,
      responsibilities: responsibilities,
      requiredSkills: requiredSkills,
      locationType: locationType?.wire,
      expectedLoad: expectedLoad?.wire,
    );
  }

  @override
  Future<Either<Failure, PageResult<PositionEntity>>> getProjectPositions(
    int projectId, {
    String? title,
    List<String>? requiredSkills,
    bool isOpen = true,
    PositionLocationType? locationType,
    PositionExpectedLoad? expectedLoad,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _positionDataSource.fetchProjectPositions(
      projectId,
      title: title,
      requiredSkills: requiredSkills,
      isOpen: isOpen,
      locationType: locationType?.wire,
      expectedLoad: expectedLoad?.wire,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
    return result.map((page) => page.map((model) => model.toEntity()));
  }

  @override
  Future<Either<Failure, PageResult<PositionEntity>>> getPositions({
    int? projectId,
    String? title,
    List<String>? requiredSkills,
    bool isOpen = true,
    PositionLocationType? locationType,
    PositionExpectedLoad? expectedLoad,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _positionDataSource.fetchPositions(
      projectId: projectId,
      title: title,
      requiredSkills: requiredSkills,
      isOpen: isOpen,
      locationType: locationType?.wire,
      expectedLoad: expectedLoad?.wire,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
    return result.map((page) => page.map((model) => model.toEntity()));
  }

  @override
  Future<Either<Failure, PositionEntity>> getPosition(String positionId) async {
    final result = await _positionDataSource.fetchPosition(positionId);
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Either<Failure, void>> updatePosition(
    String positionId, {
    String? title,
    String? description,
    String? responsibilities,
    List<String>? requiredSkills,
    PositionLocationType? locationType,
    PositionExpectedLoad? expectedLoad,
  }) {
    return _positionDataSource.updatePosition(
      positionId,
      title: title,
      description: description,
      responsibilities: responsibilities,
      requiredSkills: requiredSkills,
      locationType: locationType?.wire,
      expectedLoad: expectedLoad?.wire,
    );
  }

  @override
  Future<Either<Failure, void>> deletePosition(String positionId) {
    return _positionDataSource.deletePosition(positionId);
  }

  @override
  Future<Either<Failure, PageResult<ApplicationEntity>>> getPositionApplications(
    String positionId, {
    int? projectId,
    int? candidateId,
    ApplicationStatus? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _positionDataSource.fetchPositionApplications(
      positionId,
      projectId: projectId,
      candidateId: candidateId,
      status: status?.wire,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
    return result.map((page) => page.map((model) => model.toEntity()));
  }

  @override
  Future<Either<Failure, void>> applyToPosition(
    String positionId, {
    String? message,
  }) {
    return _positionDataSource.applyToPosition(positionId, message: message);
  }

  // --- Applications ----------------------------------------------------------

  @override
  Future<Either<Failure, PageResult<ApplicationEntity>>> getApplications({
    int? projectId,
    String? positionId,
    int? candidateId,
    ApplicationStatus? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _applicationDataSource.fetchApplications(
      projectId: projectId,
      positionId: positionId,
      candidateId: candidateId,
      status: status?.wire,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
    return result.map((page) => page.map((model) => model.toEntity()));
  }

  @override
  Future<Either<Failure, PageResult<ApplicationEntity>>> getMyApplications({
    String? positionId,
    int? projectId,
    ApplicationStatus? status,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _applicationDataSource.fetchMyApplications(
      positionId: positionId,
      projectId: projectId,
      status: status?.wire,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
    return result.map((page) => page.map((model) => model.toEntity()));
  }

  @override
  Future<Either<Failure, void>> approveApplication(String applicationId) {
    return _applicationDataSource.approveApplication(applicationId);
  }

  @override
  Future<Either<Failure, void>> rejectApplication(String applicationId) {
    return _applicationDataSource.rejectApplication(applicationId);
  }

  // --- Project roles ---------------------------------------------------------

  @override
  Future<Either<Failure, PageResult<ProjectRoleEntity>>> getProjectRoles({
    String? name,
    int page = 1,
    int pageSize = 20,
    String? sort,
  }) async {
    final result = await _projectDataSource.fetchProjectRoles(
      name: name,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
    return result.map((page) => page.map((model) => model.toEntity()));
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl(
    ref.watch(projectRemoteDataSourceProvider),
    ref.watch(positionRemoteDataSourceProvider),
    ref.watch(applicationRemoteDataSourceProvider),
  );
});
