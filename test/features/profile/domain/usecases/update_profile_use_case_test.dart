import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/domain/usecases/update_profile_use_case.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late UpdateProfileUseCase useCase;
  late MockProfileRepository mockProfileRepository;

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    useCase = UpdateProfileUseCase(mockProfileRepository);
  });

  final tBirthday = DateTime(1995, 5, 20);

  test('should call ProfileRepository.updateProfile and return void on success', () async {
    // Arrange
    when(
      () => mockProfileRepository.updateProfile(
        1,
        specialization: any(named: 'specialization'),
        displayName: any(named: 'displayName'),
        bio: any(named: 'bio'),
        skills: any(named: 'skills'),
        dateBirthday: any(named: 'dateBirthday'),
      ),
    ).thenAnswer((_) async => const Right(null));

    // Act
    final result = await useCase.execute(
      1,
      specialization: 'Backend engineer',
      displayName: 'Jane',
      bio: 'Hello',
      skills: const ['dart', 'flutter'],
      dateBirthday: tBirthday,
    );

    // Assert
    expect(result, const Right<Failure, void>(null));
    verify(
      () => mockProfileRepository.updateProfile(
        1,
        specialization: 'Backend engineer',
        displayName: 'Jane',
        bio: 'Hello',
        skills: const ['dart', 'flutter'],
        dateBirthday: tBirthday,
      ),
    ).called(1);
  });

  test('should return the repository Failure when the update fails', () async {
    // Arrange
    const tFailure = ApiFailure(
      code: 'ACCESS_DENIED',
      message: 'Cannot edit this profile',
      detail: {},
      status: 403,
    );
    when(
      () => mockProfileRepository.updateProfile(
        1,
        specialization: any(named: 'specialization'),
        displayName: any(named: 'displayName'),
        bio: any(named: 'bio'),
        skills: any(named: 'skills'),
        dateBirthday: any(named: 'dateBirthday'),
      ),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase.execute(1, displayName: 'Jane');

    // Assert
    expect(result, const Left(tFailure));
  });

  test('should return InputFailure and never hit the repository for a non-positive profileId', () async {
    // Act
    final result = await useCase.execute(0, displayName: 'Jane');

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });

  test('should return InputFailure and never hit the repository when displayName is too long', () async {
    // Arrange — api-docs §4.4: display_name valid length is ≤ 99 chars.
    final tooLongName = 'a' * 100;

    // Act
    final result = await useCase.execute(1, displayName: tooLongName);

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });

  test('should return InputFailure and never hit the repository when bio is too long', () async {
    // Arrange — api-docs §4.4: bio valid length is ≤ 1023 chars.
    final tooLongBio = 'a' * 1024;

    // Act
    final result = await useCase.execute(1, bio: tooLongBio);

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });

  test('should return InputFailure and never hit the repository when a skill is too long', () async {
    // Arrange — api-docs §4.4: each skill must be ≤ 30 chars.
    final tooLongSkill = 'a' * 31;

    // Act
    final result = await useCase.execute(1, skills: ['dart', tooLongSkill]);

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });

  test('should allow a displayName exactly at the 99 character limit', () async {
    // Arrange
    final maxLengthName = 'a' * 99;
    when(
      () => mockProfileRepository.updateProfile(
        1,
        specialization: any(named: 'specialization'),
        displayName: any(named: 'displayName'),
        bio: any(named: 'bio'),
        skills: any(named: 'skills'),
        dateBirthday: any(named: 'dateBirthday'),
      ),
    ).thenAnswer((_) async => const Right(null));

    // Act
    final result = await useCase.execute(1, displayName: maxLengthName);

    // Assert
    expect(result, const Right<Failure, void>(null));
  });
}
