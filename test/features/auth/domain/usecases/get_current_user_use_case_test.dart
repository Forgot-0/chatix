import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/features/auth/domain/usecases/get_current_user_use_case.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/core/error/failures.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late GetCurrentUserUseCase useCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = GetCurrentUserUseCase(mockAuthRepository);
  });

  const tUser = UserEntity(id: 1, username: 'testuser', email: 'test@example.com');

  test('should return UserEntity from GET /users/me/ on success', () async {
    // Arrange
    when(
      () => mockAuthRepository.getCurrentUser(),
    ).thenAnswer((_) async => const Right(tUser));

    // Act
    final result = await useCase.execute();

    // Assert
    expect(result, const Right(tUser));
    verify(() => mockAuthRepository.getCurrentUser()).called(1);
  });

  test('should return the repository Failure when the token is invalid', () async {
    // Arrange
    const tFailure = ApiFailure(
      code: 'INVALID_TOKEN',
      message: 'Invalid token',
      detail: {},
      status: 403,
    );
    when(
      () => mockAuthRepository.getCurrentUser(),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase.execute();

    // Assert
    expect(result, const Left(tFailure));
  });
}
