import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/domain/usecases/get_profile_use_case.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late GetProfileUseCase useCase;
  late MockProfileRepository mockProfileRepository;

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    useCase = GetProfileUseCase(mockProfileRepository);
  });

  const tProfile = ProfileEntity(
    id: 42,
    avatars: {},
    specialization: null,
    displayName: null,
    bio: null,
    dateBirthday: null,
    skills: [],
    contacts: [],
  );

  test('should return ProfileEntity from GET /profiles/{id}/ on success', () async {
    // Arrange
    when(() => mockProfileRepository.getProfile(42)).thenAnswer((_) async => const Right(tProfile));

    // Act
    final result = await useCase.execute(42);

    // Assert
    expect(result, const Right(tProfile));
    verify(() => mockProfileRepository.getProfile(42)).called(1);
  });

  test('should return the repository Failure when the profile is not found', () async {
    // Arrange
    const tFailure = ApiFailure(
      code: 'NOT_FOUND_PROFILE',
      message: 'Profile not found',
      detail: {'profile_id': 42},
      status: 404,
    );
    when(() => mockProfileRepository.getProfile(42)).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase.execute(42);

    // Assert
    expect(result, const Left(tFailure));
  });

  test('should return InputFailure and never hit the repository for a non-positive profileId', () async {
    // Act
    final result = await useCase.execute(0);

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });
}
