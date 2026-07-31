import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `POST /projects/` 🔒 (api-docs §5.1).
class CreateProjectUseCase {
  final ProjectRepository _repository;

  CreateProjectUseCase(this._repository);

  /// Max projects a single user may own (api-docs §5.1). The server enforces
  /// this (`MAX_PROJECTS_LIMIT_EXCEEDED`); [currentProjectCount] lets the
  /// caller fail fast when it already knows the count (e.g. from
  /// `getMyProjects`) instead of spending a round-trip on a guaranteed 400.
  static const int maxProjectsPerUser = 3;

  Future<Either<Failure, void>> execute({
    required String name,
    required String slug,
    String? smallDescription,
    String? description,
    ProjectVisibility? visibility,
    Map<String, dynamic>? metaData,
    List<String>? tags,
    int? currentProjectCount,
  }) {
    if (name.trim().isEmpty) return _fail('Project name is required');
    if (name.length > 200) return _fail('Project name must be 200 characters or fewer');
    if (slug.trim().isEmpty) return _fail('Project slug is required');
    if (slug.length > 210) return _fail('Project slug must be 210 characters or fewer');
    if (tags != null && tags.any((t) => t.length > 50)) {
      return _fail('Each tag must be 50 characters or fewer');
    }
    if (currentProjectCount != null && currentProjectCount >= maxProjectsPerUser) {
      return _fail('You can own at most $maxProjectsPerUser projects');
    }
    return _repository.createProject(
      name: name,
      slug: slug,
      smallDescription: smallDescription,
      description: description,
      visibility: visibility,
      metaData: metaData,
      tags: tags,
    );
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
