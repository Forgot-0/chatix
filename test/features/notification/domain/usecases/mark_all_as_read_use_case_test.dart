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
    when(() => mockRepository.markAllAsRead()).thenAnswer((_) async => const Right(7));

    final result = await useCase.execute();

    expect(result, const Right<Failure, int>(7));
    verify(() => mockRepository.markAllAsRead()).called(1);
  });

  test('returns 0 when there was nothing unread', () async {
    when(() => mockRepository.markAllAsRead()).thenAnswer((_) async => const Right(0));

    final result = await useCase.execute();

    expect(result, const Right<Failure, int>(0));
    expect(result.toNullable(), 0);
  });

  test('propagates a Failure without translating it', () async {
    const tFailure = ApiFailure(
      code: 'UNKNOWN',
      message: 'Something broke',
      detail: {},
      status: 500,
    );
    when(() => mockRepository.markAllAsRead()).thenAnswer((_) async => const Left(tFailure));

    final result = await useCase.execute();

    expect(result, const Left<Failure, int>(tFailure));
    expect(result.isLeft(), isTrue);
  });

  test('surfaces a network failure so the UI can keep the unread badge', () async {
    const tFailure = NetworkFailure();
    when(() => mockRepository.markAllAsRead()).thenAnswer((_) async => const Left(tFailure));

    final result = await useCase.execute();

    expect(result, const Left<Failure, int>(tFailure));
  });

  test('does not call the repository more than once per invocation', () async {
    when(() => mockRepository.markAllAsRead()).thenAnswer((_) async => const Right(3));

    await useCase.execute();

    verify(() => mockRepository.markAllAsRead()).called(1);
    verifyNoMoreInteractions(mockRepository);
  });
}
