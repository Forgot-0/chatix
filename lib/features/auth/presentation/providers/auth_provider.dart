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

/// Session state: `null` = signed out, otherwise the current [UserEntity].
/// Failures surface through `AsyncValue.error` so screens can read
/// `state.error` (a [Failure]) and show a message.
class AuthController extends AsyncNotifier<UserEntity?> {
  @override
  Future<UserEntity?> build() async {
    _listenForSessionExpiry();

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

  /// Subscribes to the HTTP layer's "this session is gone" bus.
  ///
  /// ### Why the controller listens instead of the screens
  ///
  /// A session can die at any moment: the refresh token is revoked from
  /// another device, the session row is deactivated, the token is
  /// blacklisted (api-docs §2.3, §3.4). Whichever request happens to be in
  /// flight when that happens is arbitrary — it might be a background
  /// notification-badge poll with no screen attached at all. Making each
  /// screen recognise its own 401 and navigate would mean every screen
  /// re-implementing the same reaction, every new screen being a place to
  /// forget it, and no reaction whatsoever from code with no `BuildContext`.
  ///
  /// Instead there is exactly one reaction, here: flip to signed-out. The
  /// router watches this provider and redirects to `/login` on its own (see
  /// `core/router/app_router.dart`), which makes the behaviour identical no
  /// matter where in the app the user was standing.
  ///
  /// Re-subscribing on every `build()` is correct: the old subscription is
  /// cancelled through [Ref.onDispose] when the notifier is rebuilt or
  /// disposed, so there is never more than one live listener.
  void _listenForSessionExpiry() {
    final subscription = ref
        .read(sessionExpiredSignalProvider)
        .stream
        .listen(_onSessionExpired);
    ref.onDispose(subscription.cancel);
  }

  /// Turns a session-expiry signal into signed-out state.
  ///
  /// Idempotent by the `state.value == null` guard: several requests can fail
  /// together (a screen that fires three calls on open), and each one emits.
  /// Without the guard the second signal would re-notify listeners with an
  /// identical state and make the router re-evaluate its redirect for
  /// nothing.
  ///
  /// Note this reports **data(null)**, not `AsyncValue.error`. An expired
  /// session is not an error the user made or can retry — it is simply the
  /// signed-out state, and modelling it as an error would (a) make
  /// `isAuthenticated` ambiguous and (b) pop an error snackbar on top of the
  /// login screen the router is already sending them to. The token is
  /// already gone from storage by the time this runs — `AuthInterceptor`
  /// clears it before signalling.
  void _onSessionExpired(SessionExpiredReason reason) {
    if (state.value == null) return;

    debugPrint('Session ended (${reason.name}) — signing out.');
    state = const AsyncValue.data(null);
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

/// `authState.isAuthenticated` for the router — true once we're confidently
/// resolved to a logged-in user. Defined on the watched [AsyncValue] rather
/// than on the notifier so it stays reactive: watching `authProvider.notifier`
/// directly would NOT rebuild on state changes, only on notifier identity
/// changes.
///
/// Note: riverpod 3.x's `AsyncValue.value` is already the nullable/"don't
/// throw" accessor (it's `requireValue` that throws) — there is no separate
/// `valueOrNull` like in riverpod 2.x.
extension AuthStateX on AsyncValue<UserEntity?> {
  bool get isAuthenticated => value != null;

  /// Whether the session question is still open — a cold start reading the
  /// stored token, or a login/register/logout in flight.
  ///
  /// The router uses this to hold its redirect decision instead of bouncing a
  /// returning user through `/login` before their stored token resolves.
  /// `isLoading` alone is not enough: riverpod keeps `isLoading == true`
  /// during a *refresh* that already has data underneath it, and in that case
  /// there is a perfectly good answer to give.
  bool get isSessionUnresolved => isLoading && !hasValue;
}
