import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';

/// `PATCH /notifications/read_all/` 🔒 (api-docs §8.4) — mark every unread
/// notification as read, returning **how many** were affected.
///
/// The count is worth surfacing (e.g. "7 notifications marked as read") and
/// is also the cheapest way for the caller to know whether anything actually
/// changed: `0` means the inbox was already clear, so the badge and list need
/// no refetch.
class MarkAllAsReadUseCase {
  final NotificationRepository _repository;

  MarkAllAsReadUseCase(this._repository);

  Future<Either<Failure, int>> execute() {
    return _repository.markAllAsRead();
  }
}
