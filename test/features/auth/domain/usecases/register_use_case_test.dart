import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/features/auth/domain/usecases/register_use_case.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/core/error/failures.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late RegisterUseCase useCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = RegisterUseCase(mockAuthRepository);
  });

  const tUsername = 'testuser';
  const tEmail = 'test@example.com';
  const tPassword = 'Password123!';
  const tUser = UserEntity(id: 1, username: tUsername, email: tEmail);

  test('should return UserEntity when registration is successful', () async {
    // Arrange
    when(
      () => mockAuthRepository.register(
        username: tUsername,
        email: tEmail,
        password: tPassword,
        passwordRepeat: tPassword,
      ),
    ).thenAnswer((_) async => const Right(tUser));

    // Act
    final result = await useCase.execute(
      username: tUsername,
      email: tEmail,
      password: tPassword,
      passwordRepeat: tPassword,
    );

    // Assert
    expect(result, const Right(tUser));
    verify(
      () => mockAuthRepository.register(
        username: tUsername,
        email: tEmail,
        password: tPassword,
        passwordRepeat: tPassword,
      ),
    ).called(1);
  });

  test('should return the repository Failure when registration fails (e.g. duplicate)', () async {
    // Arrange
    const tFailure = ApiFailure(
      code: 'DUPLICATE_USER',
      message: 'Username already taken',
      detail: {'field': 'username', 'value': tUsername},
      status: 409,
    );
    when(
      () => mockAuthRepository.register(
        username: tUsername,
        email: tEmail,
        password: tPassword,
        passwordRepeat: tPassword,
      ),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase.execute(
      username: tUsername,
      email: tEmail,
      password: tPassword,
      passwordRepeat: tPassword,
    );

    // Assert
    expect(result, const Left(tFailure));
  });

  test('should return InputFailure and never hit the repository when a field is empty', () async {
    // Act
    final result = await useCase.execute(
      username: '',
      email: tEmail,
      password: tPassword,
      passwordRepeat: tPassword,
    );

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockAuthRepository);
  });

  test('should return InputFailure and never hit the repository when passwords do not match', () async {
    // Act
    final result = await useCase.execute(
      username: tUsername,
      email: tEmail,
      password: tPassword,
      passwordRepeat: 'SomethingElse123!',
    );

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockAuthRepository);
  });
}
