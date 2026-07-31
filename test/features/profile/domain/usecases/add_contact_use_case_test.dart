import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/domain/usecases/add_contact_use_case.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late AddContactUseCase useCase;
  late MockProfileRepository mockProfileRepository;

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    useCase = AddContactUseCase(mockProfileRepository);
  });

  test('should call ProfileRepository.addContact and return void on success', () async {
    // Arrange
    when(
      () => mockProfileRepository.addContact(1, provider: 'telegram', contact: '@jane'),
    ).thenAnswer((_) async => const Right(null));

    // Act
    final result = await useCase.execute(1, provider: 'telegram', contact: '@jane');

    // Assert
    expect(result, const Right<Failure, void>(null));
    verify(
      () => mockProfileRepository.addContact(1, provider: 'telegram', contact: '@jane'),
    ).called(1);
  });

  test('should return the repository Failure when the call fails', () async {
    // Arrange
    const tFailure = ApiFailure(
      code: 'ACCESS_DENIED',
      message: 'Cannot edit this profile',
      detail: {},
      status: 403,
    );
    when(
      () => mockProfileRepository.addContact(1, provider: 'telegram', contact: '@jane'),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase.execute(1, provider: 'telegram', contact: '@jane');

    // Assert
    expect(result, const Left(tFailure));
  });

  test('should return InputFailure and never hit the repository for a non-positive profileId', () async {
    // Act
    final result = await useCase.execute(0, provider: 'telegram', contact: '@jane');

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });

  test('should return InputFailure and never hit the repository when provider is empty', () async {
    // Act
    final result = await useCase.execute(1, provider: '', contact: '@jane');

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });

  test('should return InputFailure and never hit the repository when contact is empty', () async {
    // Act
    final result = await useCase.execute(1, provider: 'telegram', contact: '');

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockProfileRepository);
  });
}
