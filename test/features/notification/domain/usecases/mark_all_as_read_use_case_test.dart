import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';
import 'package:chatix/features/notification/domain/usecases/mark_all_as_read_use_case.dart';

class MockNotificationRepository extends Mock implements NotificationRepository {}

void main() {
  late MarkAllAsReadUseCase useCase;
  late MockNotificationRepository mockRepository;

  setUp(() {
    mockRepository = MockNotificationRepository();
    useCase = MarkAllAsReadUseCase(mockRepository);
  });

  test('returns the number of notifications the server marked as read', () async {
    // Arrange — api-docs §8.4: `PATCH /notifications/read_all/` answers with a
    // BARE number (e.g. `7`), not an object. By the time it reaches the use
    // case the datasource has already unwrapped it into an int; this asserts
    // that the count is carried through rather than discarded (the screen
    // reports it back to the user).
    when(() => mockRepository.markAllAsRead()).thenAnswer((_) async => const Right(7));

    // Act
    final result = await useCase.execute();

    // Assert
    expect(result, const Right<Failure, int>(7));
    verify(() => mockRepository.markAllAsRead()).called(1);
  });

  test('returns 0 when there was nothing unread', () async {
    // Arrange — a legitimate success, not an error: the inbox was already
    // clear. Callers use the 0 to skip refetching the list and the badge.
    when(() => mockRepository.markAllAsRead()).thenAnswer((_) async => const Right(0));

    // Act
    final result = await useCase.execute();

    // Assert
    expect(result, const Right<Failure, int>(0));
    expect(result.toNullable(), 0);
  });

  test('propagates a Failure without translating it', () async {
    // Arrange
    const tFailure = ApiFailure(
      code: 'UNKNOWN',
      message: 'Something broke',
      detail: {},
      status: 500,
    );
    when(() => mockRepository.markAllAsRead()).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase.execute();

    // Assert
    expect(result, const Left<Failure, int>(tFailure));
    expect(result.isLeft(), isTrue);
  });

  test('surfaces a network failure so the UI can keep the unread badge', () async {
    // Arrange — offline "mark all as read" must NOT be mistaken for a
    // successful 0: the badge would be cleared while the server still holds
    // unread notifications.
    const tFailure = NetworkFailure();
    when(() => mockRepository.markAllAsRead()).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase.execute();

    // Assert
    expect(result, const Left<Failure, int>(tFailure));
  });

  test('does not call the repository more than once per invocation', () async {
    // Arrange — the endpoint is a bulk write; an accidental double call would
    // be a second pointless round-trip (and a confusing second count).
    when(() => mockRepository.markAllAsRead()).thenAnswer((_) async => const Right(3));

    // Act
    await useCase.execute();

    // Assert
    verify(() => mockRepository.markAllAsRead()).called(1);
    verifyNoMoreInteractions(mockRepository);
  });
}
