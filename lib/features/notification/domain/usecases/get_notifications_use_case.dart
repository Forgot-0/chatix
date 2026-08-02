import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/notification/domain/entities/notification_entity.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';

/// `GET /notifications/` 🔒 (api-docs §8.2) — the notification inbox, one
/// page at a time.
///
/// The use case exists (rather than screens calling the repository) to hold
/// the two rules that would otherwise be re-implemented per call site:
/// clamping [pageSize] to the documented server bounds, and refusing a page
/// number below 1.
class GetNotificationsUseCase {
  /// `page_size` bounds shared by every paginated list (api-docs §1.5:
  /// `ge=1, le=100`). Sending 0 or 500 is a `422` from FastAPI's validation
  /// layer, whose error body does not follow the app's own error envelope
  /// (api-docs §2.2) — cheaper to keep in range than to explain.
  static const int maxPageSize = 100;
  static const int minPageSize = 1;

  final NotificationRepository _repository;

  GetNotificationsUseCase(this._repository);

  /// [isRead] `null` = all, `false` = unread only, `true` = read only.
  ///
  /// [sort] defaults to newest-first, the only ordering the inbox UI offers;
  /// the format is `"field:direction"` (api-docs §1.7).
  Future<Either<Failure, PageResult<NotificationEntity>>> execute({
    bool? isRead,
    int page = 1,
    int pageSize = 20,
    String sort = 'created_at:desc',
  }) {
    return _repository.getNotifications(
      isRead: isRead,
      // A caller that computed `page` from a previous response (e.g.
      // `page - 1` while at page 1) must not turn that into a 422.
      page: page < 1 ? 1 : page,
      pageSize: pageSize.clamp(minPageSize, maxPageSize),
      sort: sort,
    );
  }
}
