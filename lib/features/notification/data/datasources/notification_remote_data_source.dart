import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/notification/data/models/notification_model.dart';

/// Talks to `/devices/*` and `/notifications/*` (api-docs §8) via
/// [ApiClient], which already maps Dio responses/errors into
/// `Either<Failure, dynamic>`.
///
/// This layer only builds paths/queries/bodies and parses JSON into models —
/// no Model→Entity mapping (that's `NotificationRepositoryImpl`) and no
/// business rules (that's `domain/usecases/*`).
abstract class NotificationRemoteDataSource {
  /// `POST /devices/` 🔒 (api-docs §8.1). `201`, empty body.
  Future<Either<Failure, void>> registerDevice({
    required String platform,
    required String token,
    required String deviceName,
  });

  /// `GET /notifications/` 🔒 (api-docs §8.2) — `PageResult<NotificationDTO>`.
  Future<Either<Failure, PageResult<NotificationModel>>> fetchNotifications({
    bool? isRead,
    int page = 1,
    int pageSize = 20,
    String sort = 'created_at:desc',
  });

  /// `GET /notifications/unread_count/` 🔒 (api-docs §8.3).
  Future<Either<Failure, int>> fetchUnreadCount();

  /// `PATCH /notifications/{notification_id}/read/` 🔒 (api-docs §8.4).
  Future<Either<Failure, void>> markAsRead(int notificationId, {bool isRead = true});

  /// `PATCH /notifications/read_all/` 🔒 (api-docs §8.4) — returns the count.
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
    // ⚠️ `/devices/` is a top-level path, NOT `/notifications/devices/`
    // (api-docs §8 preamble).
    //
    // `platform` is passed straight through: it is validated/derived by
    // `RegisterDeviceUseCase` via `DevicePlatform.wire`, which is the only
    // thing that produces the upper-case values the backend accepts.
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
        // Omitted entirely when null — "all notifications". Sending
        // `is_read=null` would be read as a provided-but-empty filter.
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
      // `{ "unread_count": number }` (api-docs §8.3) — an object here, unlike
      // `read_all` below. Read via `num` because JSON integers can arrive as
      // `double` after a round-trip through some clients/proxies.
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
      // ⚠️ api-docs §8.4: the body is a **bare number** (`7`), not an object.
      // There is no key to read, so this cannot go through a model.
      //
      // What `data` actually is depends on Dio's content-type sniffing:
      // * `application/json` + `7`  → already an `int` (Dio ran jsonDecode);
      // * `text/plain` or a missing content-type → the String `"7"`;
      // * some proxies normalise JSON numbers to `double` → `7.0`.
      //
      // All three are accepted below. A body we still can't read as a number
      // degrades to `0` ("nothing reported marked") rather than throwing —
      // the PATCH itself already succeeded by the time we get here, and the
      // count is informational; failing the call would wrongly tell the user
      // their inbox wasn't cleared.
      return _asInt(data) ?? 0;
    });
  }

  /// `int` out of an `int` / `double` / numeric `String` / `null`.
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
