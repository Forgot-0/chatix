import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/notification/domain/entities/notification_entity.dart';

/// `/devices/*` and `/notifications/*` (api-docs §8).
///
/// ⚠️ The two paths are **siblings**, not nested: it is `POST /devices/`, not
/// `POST /notifications/devices/` (api-docs §8 preamble). They live on one
/// repository because registering a device is only ever done in service of
/// notifications.
///
/// ### What this repository does *not* do
///
/// It does not receive pushes. Delivery of an FCM/APNs message to the handset
/// is `core/notifications/NotificationService`'s job; this repository only
/// (a) hands the device token to our backend so it *can* be pushed to, and
/// (b) reads the server-side notification inbox over REST.
///
/// ### No realtime
///
/// The WebSocket protocol (api-docs §7) carries **no** notification events —
/// there is no `notification.created` frame to subscribe to. The unread badge
/// and the list are therefore poll/refresh driven (see
/// `NotificationBadgeController`); do not build UI that assumes a live push
/// into this feature.
abstract class NotificationRepository {
  /// `POST /devices/` 🔒 (api-docs §8.1) — register this device's FCM/APNs
  /// token for push delivery. Response is `201` with an empty body.
  ///
  /// [platform] must be exactly one of `"IOS"`, `"WEB"`, `"ANDROID"`. Use
  /// `DevicePlatform.current.wire` rather than assembling the string by hand
  /// — `Platform.operatingSystem` is lower-case and would be rejected.
  ///
  /// [token] is the token obtained from `NotificationService.getToken()`.
  Future<Either<Failure, void>> registerDevice({
    required String platform,
    required String token,
    required String deviceName,
  });

  /// `GET /notifications/` 🔒 (api-docs §8.2).
  ///
  /// ⚠️ Ordinary **page-based** pagination (`PageResult<T>`, api-docs §1.5) —
  /// *not* the cursor scheme the chat module uses (§1.6). `has_next` is
  /// computed client-side from `total`/`page`/`page_size` because the server
  /// does not serialize it.
  ///
  /// [isRead] filters to read (`true`) or unread (`false`) when supplied;
  /// omit it for everything. [pageSize] is capped at 100 server-side.
  Future<Either<Failure, PageResult<NotificationEntity>>> getNotifications({
    bool? isRead,
    int page = 1,
    int pageSize = 20,
    String sort = 'created_at:desc',
  });

  /// `GET /notifications/unread_count/` 🔒 (api-docs §8.3) — the badge number,
  /// unwrapped from the `{ "unread_count": n }` envelope.
  Future<Either<Failure, int>> getUnreadCount();

  /// `PATCH /notifications/{notification_id}/read/` 🔒 (api-docs §8.4).
  /// Passing `isRead: false` un-reads a notification again — the flag is a
  /// real request field, not a fixed `true`.
  ///
  /// Failure codes: `403 NOTIFICATION_ACCESS_DENIED`, `404
  /// NOT_FOUND_NOTIFICATION` (api-docs §2.8).
  Future<Either<Failure, void>> markAsRead(int notificationId, {bool isRead = true});

  /// `PATCH /notifications/read_all/` 🔒 (api-docs §8.4) → **how many** were
  /// marked.
  ///
  /// ⚠️ The response body is a **bare number** (`7`), not an object — see
  /// `NotificationRemoteDataSourceImpl.markAllAsRead` for the parsing that
  /// this quirk forces.
  Future<Either<Failure, int>> markAllAsRead();
}
