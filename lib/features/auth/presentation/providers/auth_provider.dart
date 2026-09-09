import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/auth/session_events.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/notifications/notification_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/notification/presentation/providers/notification_providers.dart';

class AuthController extends AsyncNotifier<UserEntity?> {
  @override
  Future<UserEntity?> build() async {
    _listenForSessionExpiry();

    final token = await ref
        .read(secureStorageServiceProvider)
        .read(key: AppConstants.accessTokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }

    final result = await ref.read(getCurrentUserUseCaseProvider).execute();
    return result.fold((failure) => null, (user) => user);
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();

    final loginResult = await ref
        .read(loginUseCaseProvider)
        .execute(username: username, password: password);

    if (loginResult.isLeft()) {
      state = AsyncValue.error(
        loginResult.getLeft().toNullable()!,
        StackTrace.current,
      );
      return;
    }

    await _refreshCurrentUser();

    await _registerDeviceForPush();
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String passwordRepeat,
  }) async {
    state = const AsyncValue.loading();

    final registerResult = await ref
        .read(registerUseCaseProvider)
        .execute(
          username: username,
          email: email,
          password: password,
          passwordRepeat: passwordRepeat,
        );

    if (registerResult.isLeft()) {
      state = AsyncValue.error(
        registerResult.getLeft().toNullable()!,
        StackTrace.current,
      );
      return;
    }

    await login(username: username, password: password);
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();

    final result = await ref.read(logoutUseCaseProvider).execute();

    final tokenStillPresent = await ref
        .read(secureStorageServiceProvider)
        .read(key: AppConstants.accessTokenKey);

    if (tokenStillPresent != null && tokenStillPresent.isNotEmpty) {
      state = AsyncValue.error(
        result.getLeft().toNullable() ??
            const ServerFailure(message: 'Logout failed'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.data(null);
  }

  Future<void> _refreshCurrentUser() async {
    final result = await ref.read(getCurrentUserUseCaseProvider).execute();
    state = result.fold(
      (failure) => AsyncValue.error(failure, StackTrace.current),
      (user) => AsyncValue.data(user),
    );
  }

  void _listenForSessionExpiry() {
    final subscription = ref
        .read(sessionExpiredSignalProvider)
        .stream
        .listen(_onSessionExpired);
    ref.onDispose(subscription.cancel);
  }

  void _onSessionExpired(SessionExpiredReason reason) {
    if (state.value == null) return;

    debugPrint('Session ended (${reason.name}) — signing out.');
    state = const AsyncValue.data(null);
  }

  Future<void> _registerDeviceForPush() async {
    if (state.value == null) return;

    try {
      final notificationService = ref.read(notificationServiceProvider);
      final token = await notificationService.getToken();
      if (token == null || token.isEmpty) return;

      await ref
          .read(registerDeviceUseCaseProvider)
          .execute(token: token, deviceName: AppConstants.appName);
    } catch (error, stackTrace) {
      debugPrint('Push device registration skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthController, UserEntity?>(
  AuthController.new,
);

extension AuthStateX on AsyncValue<UserEntity?> {
  bool get isAuthenticated => value != null;

  bool get isSessionUnresolved => isLoading && !hasValue;
}
