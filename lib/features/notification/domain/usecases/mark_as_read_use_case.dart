import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';

/// `PATCH /notifications/{notification_id}/read/` 🔒 (api-docs §8.4).
///
/// [isRead] is a real request field, so this same use case also *un*-reads a
/// notification when passed `false` — there is no separate endpoint for that.
class MarkAsReadUseCase {
  final NotificationRepository _repository;

  MarkAsReadUseCase(this._repository);

  Future<Either<Failure, void>> execute(int notificationId, {bool isRead = true}) {
    return _repository.markAsRead(notificationId, isRead: isRead);
  }
}
