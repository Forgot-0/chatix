import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/features/auth/domain/usecases/login_use_case.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/core/error/failures.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late LoginUseCase useCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = LoginUseCase(mockAuthRepository);
  });

  const tUsername = 'testuser';
  const tPassword = 'Password123!';

  test('should call AuthRepository.login and return void on success', () async {
    // Arrange
    when(
      () => mockAuthRepository.login(username: tUsername, password: tPassword),
    ).thenAnswer((_) async => const Right(null));

    // Act
    final result = await useCase.execute(username: tUsername, password: tPassword);

    // Assert
    expect(result, const Right<Failure, void>(null));
    verify(
      () => mockAuthRepository.login(username: tUsername, password: tPassword),
    ).called(1);
  });

  test('should return the repository Failure when login fails', () async {
    // Arrange
    const tFailure = ApiFailure(
      code: 'WRONG_LOGIN_DATA',
      message: 'Incorrect username or password',
      detail: {'username': tUsername},
      status: 400,
    );
    when(
      () => mockAuthRepository.login(username: tUsername, password: tPassword),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase.execute(username: tUsername, password: tPassword);

    // Assert
    expect(result, const Left(tFailure));
    verify(
      () => mockAuthRepository.login(username: tUsername, password: tPassword),
    ).called(1);
  });

  test('should return InputFailure and never hit the repository when username is empty', () async {
    // Act
    final result = await useCase.execute(username: '', password: tPassword);

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockAuthRepository);
  });

  test('should return InputFailure and never hit the repository when password is empty', () async {
    // Act
    final result = await useCase.execute(username: tUsername, password: '');

    // Assert
    result.fold(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('Should have returned a failure'),
    );
    verifyZeroInteractions(mockAuthRepository);
  });
}
