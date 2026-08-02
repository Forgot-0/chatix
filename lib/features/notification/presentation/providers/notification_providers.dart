import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:chatix/features/notification/domain/usecases/get_notifications_use_case.dart';
import 'package:chatix/features/notification/domain/usecases/get_unread_count_use_case.dart';
import 'package:chatix/features/notification/domain/usecases/mark_all_as_read_use_case.dart';
import 'package:chatix/features/notification/domain/usecases/mark_as_read_use_case.dart';
import 'package:chatix/features/notification/domain/usecases/register_device_use_case.dart';

/// Domain-layer DI. `notificationRepositoryProvider` lives next to its
/// implementation in `notification_repository_impl.dart` (mirrors the auth,
/// profile and chat features' convention) — import that file directly where
/// the repository itself is required.
final getNotificationsUseCaseProvider = Provider<GetNotificationsUseCase>((ref) {
  return GetNotificationsUseCase(ref.watch(notificationRepositoryProvider));
});

final getUnreadCountUseCaseProvider = Provider<GetUnreadCountUseCase>((ref) {
  return GetUnreadCountUseCase(ref.watch(notificationRepositoryProvider));
});

final markAsReadUseCaseProvider = Provider<MarkAsReadUseCase>((ref) {
  return MarkAsReadUseCase(ref.watch(notificationRepositoryProvider));
});

final markAllAsReadUseCaseProvider = Provider<MarkAllAsReadUseCase>((ref) {
  return MarkAllAsReadUseCase(ref.watch(notificationRepositoryProvider));
});

final registerDeviceUseCaseProvider = Provider<RegisterDeviceUseCase>((ref) {
  return RegisterDeviceUseCase(ref.watch(notificationRepositoryProvider));
});
