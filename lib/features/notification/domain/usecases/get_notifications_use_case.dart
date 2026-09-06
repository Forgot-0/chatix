import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/notification/domain/entities/notification_entity.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';

class GetNotificationsUseCase {
  static const int maxPageSize = 100;
  static const int minPageSize = 1;

  final NotificationRepository _repository;

  GetNotificationsUseCase(this._repository);

  Future<Either<Failure, PageResult<NotificationEntity>>> execute({
    bool? isRead,
    int page = 1,
    int pageSize = 20,
    String sort = 'created_at:desc',
  }) {
    return _repository.getNotifications(
      isRead: isRead,
      page: page < 1 ? 1 : page,
      pageSize: pageSize.clamp(minPageSize, maxPageSize),
      sort: sort,
    );
  }
}
