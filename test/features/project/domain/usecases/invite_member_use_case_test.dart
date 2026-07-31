import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/repositories/project_repository.dart';
import 'package:chatix/features/project/domain/usecases/invite_member_use_case.dart';

class MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late InviteMemberUseCase useCase;
  late MockProjectRepository repository;

  setUp(() {
    repository = MockProjectRepository();
    useCase = InviteMemberUseCase(repository);
  });

  test('invites a member and returns void on success', () async {
    when(
      () => repository.inviteMember(1, userId: 2, roleId: 4, permissionsOverrides: null),
    ).thenAnswer((_) async => const Right(null));

    final result = await useCase.execute(1, userId: 2, roleId: 4);

    expect(result, const Right<Failure, void>(null));
    verify(
      () => repository.inviteMember(1, userId: 2, roleId: 4, permissionsOverrides: null),
    ).called(1);
  });

  test('passes through an ALREADY_MEMBER failure', () async {
    const failure = ApiFailure(
      code: 'ALREADY_MEMBER',
      message: 'Already a member',
      detail: {},
      status: 409,
    );
    when(
      () => repository.inviteMember(1, userId: 2, roleId: 4, permissionsOverrides: null),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase.execute(1, userId: 2, roleId: 4);

    expect(result, const Left(failure));
  });

  test('returns InputFailure and never hits the repository for a non-positive roleId', () async {
    final result = await useCase.execute(1, userId: 2, roleId: 0);
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have failed'),
    );
    verifyZeroInteractions(repository);
  });
}
