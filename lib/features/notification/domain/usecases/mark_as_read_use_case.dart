import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';

class MarkAsReadUseCase {
  final NotificationRepository _repository;

  MarkAsReadUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    int notificationId, {
    bool isRead = true,
  }) {
    return _repository.markAsRead(notificationId, isRead: isRead);
  }
}
