import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/notifications/notification_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/notification/presentation/providers/notification_providers.dart';

/// Session state: `null` = signed out, otherwise the current [UserEntity].
/// Failures surface through `AsyncValue.error` so screens can read
/// `state.error` (a [Failure]) and show a message.
class AuthController extends AsyncNotifier<UserEntity?> {
  @override
  Future<UserEntity?> build() async {
    final token = await ref.read(secureStorageServiceProvider).read(
      key: AppConstants.accessTokenKey,
    );
    if (token == null || token.isEmpty) {
      return null;
    }

    final result = await ref.read(getCurrentUserUseCaseProvider).execute();
    // If this fails, AuthInterceptor already tried a refresh first (it sits
    // in front of every request) and, on failure, already cleared the
    // stored access token itself — so there's nothing further to clean up
    // here, just report "signed out" rather than surfacing the error on
    // the very first frame of the app.
    return result.fold((failure) => null, (user) => user);
  }

  Future<void> login({required String username, required String password}) async {
    state = const AsyncValue.loading();

    final loginResult = await ref.read(loginUseCaseProvider).execute(
      username: username,
      password: password,
    );

    if (loginResult.isLeft()) {
      state = AsyncValue.error(
        loginResult.getLeft().toNullable()!,
        StackTrace.current,
      );
      return;
    }

    await _refreshCurrentUser();

    // Push registration (api-docs §8.1). Deliberately *after* the session is
    // established and deliberately **not awaited into the result**: see
    // [_registerDeviceForPush].
    await _registerDeviceForPush();
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String passwordRepeat,
  }) async {
    state = const AsyncValue.loading();

    final registerResult = await ref.read(registerUseCaseProvider).execute(
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

    // `POST /users/register/` does NOT return an access token (api-docs
    // §3.2) — the backend has no auto-login on registration. To still end
    // up authenticated right after a successful registration (rather than
    // bouncing the user to a separate login screen with the password
    // already gone from memory), we log in immediately with the same
    // credentials they just submitted, then load the current user.
    await login(username: username, password: password);
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();

    final result = await ref.read(logoutUseCaseProvider).execute();

    // AuthRepositoryImpl clears the stored token on success, and also on
    // any server-acknowledged failure (see its `logout()` for why) — but
    // keeps it on pure network failures so the session isn't lost while
    // offline. Re-check storage rather than assuming, so state matches
    // what actually happened.
    final tokenStillPresent = await ref.read(secureStorageServiceProvider).read(
      key: AppConstants.accessTokenKey,
    );

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

  /// Registers this device's push token with the backend (`POST /devices/`,
  /// api-docs §8.1) right after a successful login.
  ///
  /// ### This can never fail the login
  ///
  /// Every failure path below is swallowed on purpose. The user asked to sign
  /// in; whether our server can later send them a push is unrelated to
  /// whether that succeeded, and there is nothing they could do about it
  /// anyway. In particular this must not touch [state] — flipping it to
  /// `AsyncValue.error` here would sign a perfectly good session straight
  /// back out.
  ///
  /// ### Why it's expected to fail today
  ///
  /// `NotificationService` is currently wired to `DebugNotificationService`
  /// (see `core/notifications/notification_providers.dart`) — there is no
  /// Firebase project set up yet, so `getToken()` returns a fake token, or on
  /// a real FCM implementation without configuration would return `null` or
  /// throw. All three are handled:
  ///
  /// * `null`/empty token → skip quietly;
  /// * a throw from `getToken()` → caught, skipped quietly;
  /// * an unsupported platform (desktop) → `RegisterDeviceUseCase` returns a
  ///   `Left` and it is ignored.
  ///
  /// When FCM is properly configured later, the *only* change needed is
  /// swapping the implementation behind `notificationServiceProvider`. This
  /// call site, the use case, the repository and the endpoint stay as they
  /// are — that's the point of putting the integration here now rather than
  /// waiting.
  Future<void> _registerDeviceForPush() async {
    // Only for a session we actually established.
    if (state.value == null) return;

    try {
      final notificationService = ref.read(notificationServiceProvider);
      final token = await notificationService.getToken();
      if (token == null || token.isEmpty) return;

      await ref.read(registerDeviceUseCaseProvider).execute(
        token: token,
        deviceName: AppConstants.appName,
      );
    } catch (error, stackTrace) {
      // A throwing push SDK (unconfigured Firebase, missing plist/json,
      // simulator without APNs) must not take the login down with it.
      debugPrint('Push device registration skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthController, UserEntity?>(
  AuthController.new,
);

/// `authState.isAuthenticated` for the router (prompt 7 will build a fuller
/// routing scheme on top of this) — true once we're confidently resolved to
/// a logged-in user. Defined on the watched [AsyncValue] rather than on the
/// notifier so it stays reactive: watching `authProvider.notifier` directly
/// would NOT rebuild on state changes, only on notifier identity changes.
///
/// Note: riverpod 3.x's `AsyncValue.value` is already the nullable/"don't
/// throw" accessor (it's `requireValue` that throws) — there is no separate
/// `valueOrNull` like in riverpod 2.x.
extension AuthStateX on AsyncValue<UserEntity?> {
  bool get isAuthenticated => value != null;
}
