import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/notification/domain/entities/notification_entity.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';
import 'package:chatix/features/notification/domain/usecases/get_notifications_use_case.dart';

class MockNotificationRepository extends Mock implements NotificationRepository {}

void main() {
  late GetNotificationsUseCase useCase;
  late MockNotificationRepository mockRepository;

  setUp(() {
    mockRepository = MockNotificationRepository();
    useCase = GetNotificationsUseCase(mockRepository);
  });

  final tNotification = NotificationEntity(
    id: 1,
    userId: 42,
    type: NotificationType.chat,
    title: 'New message',
    message: 'Jane sent you a message',
    payload: const {'chat_id': 'a3f1c2d4-0000-4000-8000-000000000001'},
    isRead: false,
    createdAt: DateTime.utc(2026, 8, 1, 12),
    updatedAt: DateTime.utc(2026, 8, 1, 12),
  );

  late PageResult<NotificationEntity> tPage;

  setUp(() {
    tPage = PageResult<NotificationEntity>(
      items: [tNotification],
      total: 1,
      page: 1,
      pageSize: 20,
    );
  });

  void stubGetNotifications() {
    when(
      () => mockRepository.getNotifications(
        isRead: any(named: 'isRead'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => Right(tPage));
  }

  test('passes the documented defaults through to the repository', () async {
    // Arrange
    stubGetNotifications();

    // Act
    final result = await useCase.execute();

    // Assert
    expect(result, Right(tPage));
    verify(
      () => mockRepository.getNotifications(
        isRead: null,
        page: 1,
        pageSize: 20,
        // api-docs §8.2: newest first is the documented default.
        sort: 'created_at:desc',
      ),
    ).called(1);
  });

  test('forwards an explicit is_read filter and page', () async {
    // Arrange
    stubGetNotifications();

    // Act
    await useCase.execute(isRead: false, page: 3, pageSize: 50);

    // Assert — `isRead: false` must reach the repository as `false`, not be
    // dropped as "falsy/absent"; it is the unread-only filter.
    verify(
      () => mockRepository.getNotifications(
        isRead: false,
        page: 3,
        pageSize: 50,
        sort: 'created_at:desc',
      ),
    ).called(1);
  });

  test('returns the repository Failure when the call fails', () async {
    // Arrange
    const tFailure = ApiFailure(
      code: 'UNKNOWN',
      message: 'Something broke',
      detail: {},
      status: 500,
    );
    when(
      () => mockRepository.getNotifications(
        isRead: any(named: 'isRead'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => const Left(tFailure));

    // Act
    final result = await useCase.execute();

    // Assert
    expect(result, const Left<Failure, PageResult<NotificationEntity>>(tFailure));
  });

  // The backend validates `page_size` with `ge=1, le=100` and `page` with
  // `ge=1` (api-docs §1.5). A 422 from FastAPI's own validator does NOT use
  // the app's error envelope (api-docs §2.2), so out-of-range input is
  // corrected here rather than round-tripped.
  group('clamps pagination input to the documented server bounds', () {
    test('caps page_size at 100', () async {
      stubGetNotifications();

      await useCase.execute(pageSize: 500);

      verify(
        () => mockRepository.getNotifications(
          isRead: null,
          page: 1,
          pageSize: GetNotificationsUseCase.maxPageSize,
          sort: 'created_at:desc',
        ),
      ).called(1);
    });

    test('raises a non-positive page_size to 1', () async {
      stubGetNotifications();

      await useCase.execute(pageSize: 0);

      verify(
        () => mockRepository.getNotifications(
          isRead: null,
          page: 1,
          pageSize: GetNotificationsUseCase.minPageSize,
          sort: 'created_at:desc',
        ),
      ).called(1);
    });

    test('raises a page below 1 to 1', () async {
      stubGetNotifications();

      await useCase.execute(page: 0);

      verify(
        () => mockRepository.getNotifications(
          isRead: null,
          page: 1,
          pageSize: 20,
          sort: 'created_at:desc',
        ),
      ).called(1);
    });
  });

  // PageResult's derived flags are computed client-side because the server
  // does not serialize them (api-docs §1.5) — worth asserting here, since the
  // list controller's "load more" decision rests entirely on `hasNext`.
  group('page metadata survives the use case unchanged', () {
    test('hasNext is true while later pages remain', () async {
      when(
        () => mockRepository.getNotifications(
          isRead: any(named: 'isRead'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          sort: any(named: 'sort'),
        ),
      ).thenAnswer(
        (_) async => Right(
          PageResult<NotificationEntity>(
            items: [tNotification],
            total: 45,
            page: 1,
            pageSize: 20,
          ),
        ),
      );

      final result = await useCase.execute();

      final page = result.toNullable()!;
      expect(page.totalPages, 3); // ceil(45 / 20)
      expect(page.hasNext, isTrue);
      expect(page.hasPrevious, isFalse);
    });

    test('hasNext is false on the last page', () async {
      when(
        () => mockRepository.getNotifications(
          isRead: any(named: 'isRead'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          sort: any(named: 'sort'),
        ),
      ).thenAnswer(
        (_) async => Right(
          PageResult<NotificationEntity>(
            items: [tNotification],
            total: 45,
            page: 3,
            pageSize: 20,
          ),
        ),
      );

      final result = await useCase.execute(page: 3);

      final page = result.toNullable()!;
      expect(page.hasNext, isFalse);
      expect(page.hasPrevious, isTrue);
    });
  });
}
