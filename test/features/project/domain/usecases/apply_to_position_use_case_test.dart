import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';
import 'package:chatix/features/project/domain/usecases/apply_to_position_use_case.dart';

class MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late ApplyToPositionUseCase useCase;
  late MockProjectRepository repository;

  const positionId = '11111111-1111-1111-1111-111111111111';

  setUp(() {
    repository = MockProjectRepository();
    useCase = ApplyToPositionUseCase(repository);
  });

  test('applies with a message and returns void on success', () async {
    when(
      () => repository.applyToPosition(positionId, message: 'Hi!'),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase.execute(positionId, message: 'Hi!');

    expect(result, const Right<Failure, void>(null));
    verify(() => repository.applyToPosition(positionId, message: 'Hi!')).called(1);
  });

  test('applies with no message (message stays null)', () async {
    when(
      () => repository.applyToPosition(positionId, message: null),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase.execute(positionId);

    expect(result, const Right<Failure, void>(null));
    verify(() => repository.applyToPosition(positionId, message: null)).called(1);
  });

  test('returns InputFailure and never hits the repository for an empty positionId', () async {
    final result = await useCase.execute('   ', message: 'Hi!');
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have failed'),
    );
    verifyZeroInteractions(repository);
  });
}
