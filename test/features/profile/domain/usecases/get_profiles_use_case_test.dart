import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late GetProfilesUseCase useCase;
  late MockProfileRepository mockProfileRepository;

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    useCase = GetProfilesUseCase(mockProfileRepository);
  });

  const tProfile = ProfileEntity(
    id: 1,
    avatars: {},
    specialization: 'Backend',
    displayName: 'Jane Doe',
    bio: null,
    dateBirthday: null,
    skills: ['dart'],
    contacts: [],
  );

  const tPage = PageResult<ProfileEntity>(items: [tProfile], total: 1, page: 1, pageSize: 20);

  test('should call ProfileRepository.getProfiles and return the page on success', () async {
    // Arrange
    when(
      () => mockProfileRepository.getProfiles(
        username: any(named: 'username'),
        displayName: any(named: 'displayName'),
        skills: any(named: 'skills'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => const Right(tPage));

    // Act
    final result = await useCase.execute(username: 'jane');

    // Assert
    expect(result, const Right(tPage));
    verify(
      () => mockProfileRepository.getProfiles(
        username: 'jane',
        displayName: null,
        skills: null,
        page: 1,
        pageSize: 20,
        sort: null,
      ),
    ).called(1);
  });

  test('should return the repository Failure when the call fails', () async {
    // Arrange
    const tFailure = ApiFailure(code: 'UNKNOWN', message: 'Something broke', detail: {}, status: 500);
    when(
      () => mockProfileRepository.getProfiles(
        username: any(named: 'username'),
        displayName: any(named: 'displayName'),
        skills: any(named: 'skills'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase.execute();

    // Assert
    expect(result, const Left(tFailure));
  });

  test('should return InputFailure and never hit the repository when page is less than 1', () async {
    // Act
    final result = await useCase.execute(page: 0);

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });

  test('should return InputFailure and never hit the repository when pageSize is 0', () async {
    // Act
    final result = await useCase.execute(pageSize: 0);

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });

  test('should return InputFailure and never hit the repository when pageSize exceeds 100', () async {
    // Act
    final result = await useCase.execute(pageSize: 101);

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });
}
