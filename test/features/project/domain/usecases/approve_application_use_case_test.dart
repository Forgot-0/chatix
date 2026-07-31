import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';
import 'package:chatix/features/project/domain/usecases/approve_application_use_case.dart';

class MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late ApproveApplicationUseCase useCase;
  late MockProjectRepository repository;

  const applicationId = '22222222-2222-2222-2222-222222222222';

  setUp(() {
    repository = MockProjectRepository();
    useCase = ApproveApplicationUseCase(repository);
  });

  test('approves an application and returns void on success', () async {
    when(() => repository.approveApplication(applicationId))
        .thenAnswer((_) async => const Right(null));

    final result = await useCase.execute(applicationId);

    expect(result, const Right<Failure, void>(null));
    verify(() => repository.approveApplication(applicationId)).called(1);
  });

  test('passes through a NOT_PENDING_APPLICATION failure', () async {
    const failure = ApiFailure(
      code: 'NOT_PENDING_APPLICATION',
      message: 'Already decided',
      detail: {},
      status: 409,
    );
    when(() => repository.approveApplication(applicationId))
        .thenAnswer((_) async => const Left(failure));

    final result = await useCase.execute(applicationId);

    expect(result, const Left(failure));
  });

  test('returns InputFailure and never hits the repository for an empty id', () async {
    final result = await useCase.execute('');
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have failed'),
    );
    verifyZeroInteractions(repository);
  });
}
