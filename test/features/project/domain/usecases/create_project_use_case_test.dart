import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';
import 'package:chatix/features/project/domain/usecases/create_project_use_case.dart';

class MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late CreateProjectUseCase useCase;
  late MockProjectRepository repository;

  setUp(() {
    repository = MockProjectRepository();
    useCase = CreateProjectUseCase(repository);
  });

  test('creates a project and returns void on success', () async {
    when(
      () => repository.createProject(
        name: 'Chatix',
        slug: 'chatix',
        smallDescription: null,
        description: null,
        visibility: ProjectVisibility.public,
        metaData: null,
        tags: null,
      ),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase.execute(
      name: 'Chatix',
      slug: 'chatix',
      visibility: ProjectVisibility.public,
    );

    expect(result, const Right<Failure, void>(null));
    verify(
      () => repository.createProject(
        name: 'Chatix',
        slug: 'chatix',
        smallDescription: null,
        description: null,
        visibility: ProjectVisibility.public,
        metaData: null,
        tags: null,
      ),
    ).called(1);
  });

  test('passes through the MAX_PROJECTS_LIMIT_EXCEEDED failure from the server', () async {
    const failure = ApiFailure(
      code: 'MAX_PROJECTS_LIMIT_EXCEEDED',
      message: 'Limit reached',
      detail: {},
      status: 400,
    );
    when(
      () => repository.createProject(
        name: any(named: 'name'),
        slug: any(named: 'slug'),
        smallDescription: any(named: 'smallDescription'),
        description: any(named: 'description'),
        visibility: any(named: 'visibility'),
        metaData: any(named: 'metaData'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase.execute(name: 'X', slug: 'x');

    expect(result, const Left(failure));
  });

  test('returns InputFailure and never hits the repository for an empty name', () async {
    final result = await useCase.execute(name: '   ', slug: 'x');
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have failed'),
    );
    verifyZeroInteractions(repository);
  });

  test('pre-checks the per-user limit when the current count is known', () async {
    final result = await useCase.execute(
      name: 'X',
      slug: 'x',
      currentProjectCount: CreateProjectUseCase.maxProjectsPerUser,
    );
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have failed'),
    );
    verifyZeroInteractions(repository);
  });
}
