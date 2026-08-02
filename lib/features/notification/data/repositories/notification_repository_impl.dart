import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/notification/data/datasources/notification_remote_data_source.dart';
import 'package:chatix/features/notification/data/models/notification_model.dart';
import 'package:chatix/features/notification/domain/entities/notification_entity.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';

/// Maps [NotificationRemoteDataSource] models onto domain entities
/// (api-docs §8).
///
/// Deliberately thin, and deliberately **uncached**: the unread count is the
/// one number in this feature the user notices being wrong, and with no
/// realtime channel to invalidate a cache (api-docs §7 sends no notification
/// events) any local copy would drift silently. Freshness is owned by the
/// presentation layer's explicit refresh points instead.
class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remote;

  NotificationRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, void>> registerDevice({
    required String platform,
    required String token,
    required String deviceName,
  }) {
    return _remote.registerDevice(
      platform: platform,
      token: token,
      deviceName: deviceName,
    );
  }

  @override
  Future<Either<Failure, PageResult<NotificationEntity>>> getNotifications({
    bool? isRead,
    int page = 1,
    int pageSize = 20,
    String sort = 'created_at:desc',
  }) async {
    final result = await _remote.fetchNotifications(
      isRead: isRead,
      page: page,
      pageSize: pageSize,
      sort: sort,
    );
    // `PageResult.map` keeps the pagination metadata and converts only the
    // items — the model→entity step for a paginated list.
    return result.map(
      (page) => page.map((NotificationModel model) => model.toEntity()),
    );
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() {
    return _remote.fetchUnreadCount();
  }

  @override
  Future<Either<Failure, void>> markAsRead(int notificationId, {bool isRead = true}) {
    return _remote.markAsRead(notificationId, isRead: isRead);
  }

  @override
  Future<Either<Failure, int>> markAllAsRead() {
    return _remote.markAllAsRead();
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(ref.watch(notificationRemoteDataSourceProvider));
});
