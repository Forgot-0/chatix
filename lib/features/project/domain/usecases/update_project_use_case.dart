import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/domain/usecases/usecase_validators.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';

/// `PUT /projects/{project_id}/` 🔒 (api-docs §5.1). Long text is passed as
/// [description] (mapped to the `description` wire key by the data layer).
class UpdateProjectUseCase {
  final ProjectRepository _repository;

  UpdateProjectUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    int projectId, {
    String? name,
    String? description,
    ProjectVisibility? visibility,
    Map<String, dynamic>? metaData,
    List<String>? tags,
  }) {
    final err = validatePositiveId(projectId, 'projectId');
    if (err != null) return Future.value(Left(err));
    if (name != null && name.trim().isEmpty) {
      return Future.value(const Left(InputFailure(message: 'Project name cannot be empty')));
    }
    if (name != null && name.length > 200) {
      return Future.value(const Left(InputFailure(message: 'Project name must be 200 characters or fewer')));
    }
    if (tags != null && tags.any((t) => t.length > 50)) {
      return Future.value(const Left(InputFailure(message: 'Each tag must be 50 characters or fewer')));
    }
    return _repository.updateProject(
      projectId,
      name: name,
      description: description,
      visibility: visibility,
      metaData: metaData,
      tags: tags,
    );
  }
}
