import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';

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
