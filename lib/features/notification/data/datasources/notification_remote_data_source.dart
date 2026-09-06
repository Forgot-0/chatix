import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/notification/data/models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<Either<Failure, void>> registerDevice({
    required String platform,
    required String token,
    required String deviceName,
  });

  Future<Either<Failure, PageResult<NotificationModel>>> fetchNotifications({
    bool? isRead,
    int page = 1,
    int pageSize = 20,
    String sort = 'created_at:desc',
  });

  Future<Either<Failure, int>> fetchUnreadCount();

  Future<Either<Failure, void>> markAsRead(int notificationId, {bool isRead = true});

  Future<Either<Failure, int>> markAllAsRead();
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final ApiClient _apiClient;

  NotificationRemoteDataSourceImpl(this._apiClient);

  @override
  Future<Either<Failure, void>> registerDevice({
    required String platform,
    required String token,
    required String deviceName,
  }) async {
    final result = await _apiClient.post(
      '/devices/',
      data: {
        'platform': platform,
        'token': token,
        'device_name': deviceName,
      },
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, PageResult<NotificationModel>>> fetchNotifications({
    bool? isRead,
    int page = 1,
    int pageSize = 20,
    String sort = 'created_at:desc',
  }) async {
    final result = await _apiClient.get(
      '/notifications/',
      queryParameters: {
        'is_read': ?isRead,
        'page': page,
        'page_size': pageSize,
        'sort': sort,
      },
    );

    return result.map(
      (data) => PageResult<NotificationModel>.fromJson(
        data as Map<String, dynamic>,
        (item) => NotificationModel.fromJson(item as Map<String, dynamic>),
      ),
    );
  }

  @override
  Future<Either<Failure, int>> fetchUnreadCount() async {
    final result = await _apiClient.get('/notifications/unread_count/');
    return result.map((data) {
      final value = (data as Map<String, dynamic>)['unread_count'];
      return _asInt(value) ?? 0;
    });
  }

  @override
  Future<Either<Failure, void>> markAsRead(
    int notificationId, {
    bool isRead = true,
  }) async {
    final result = await _apiClient.patch(
      '/notifications/$notificationId/read/',
      data: {'is_read': isRead},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, int>> markAllAsRead() async {
    final result = await _apiClient.patch('/notifications/read_all/');

    return result.map((data) {
      return _asInt(data) ?? 0;
    });
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
    }
    return null;
  }
}

final notificationRemoteDataSourceProvider = Provider<NotificationRemoteDataSource>((ref) {
  return NotificationRemoteDataSourceImpl(ref.watch(apiClientProvider));
});
