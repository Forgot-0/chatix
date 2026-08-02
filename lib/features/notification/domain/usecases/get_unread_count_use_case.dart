import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';

/// `GET /notifications/unread_count/` 🔒 (api-docs §8.3) — the number behind
/// the bell badge.
///
/// This is polled rather than pushed: the WebSocket protocol (api-docs §7)
/// emits nothing for notifications, so there is no event that could keep the
/// badge current on its own. See `NotificationBadgeController` for when it is
/// actually called.
class GetUnreadCountUseCase {
  final NotificationRepository _repository;

  GetUnreadCountUseCase(this._repository);

  Future<Either<Failure, int>> execute() {
    return _repository.getUnreadCount();
  }
}
