import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';

/// Auth + user-session operations against `/auth/*` and `/users/*`
/// (api-docs §3). Source of truth for "who is the current user" is always
/// `GET /users/me/` via [getCurrentUser] — this repository doesn't persist
/// a `UserEntity` snapshot itself, that's the caller's (controller's) call.
abstract class AuthRepository {
  /// `POST /users/register/` (api-docs §3.2). Does NOT log the user in —
  /// the backend only issues tokens from [login]/refresh/OAuth callback.
  Future<Either<Failure, UserEntity>> register({
    required String username,
    required String email,
    required String password,
    required String passwordRepeat,
  });

  /// `POST /auth/login/` (api-docs §3.3). Only returns `access_token`
  /// (refresh token is set as an HttpOnly cookie by the server) — call
  /// [getCurrentUser] afterwards to get the [UserEntity].
  Future<Either<Failure, void>> login({
    required String username,
    required String password,
  });

  /// `POST /auth/logout/` (api-docs §3.5).
  Future<Either<Failure, void>> logout();

  /// `GET /users/me/` (api-docs §3.9).
  Future<Either<Failure, UserEntity>> getCurrentUser();

  /// `POST /auth/verifications/email/` (api-docs §3.6). Rate limit: 3/hour.
  Future<Either<Failure, void>> requestEmailVerification({required String email});

  /// `POST /auth/verifications/email/verify/` (api-docs §3.6).
  Future<Either<Failure, void>> confirmEmailVerification({required String token});

  /// `POST /auth/password-resets/` (api-docs §3.7). Rate limit: 3/hour.
  Future<Either<Failure, void>> requestPasswordReset({required String email});

  /// `POST /auth/password-resets/confirm/` (api-docs §3.7).
  Future<Either<Failure, void>> confirmPasswordReset({
    required String token,
    required String password,
    required String passwordRepeat,
  });

  /// `GET /auth/oauth/{provider}/authorize/` (or `/authorize/connect/` when
  /// [connect] is true, to link a provider to the already-logged-in
  /// account) — returns a URL to open in a browser/WebView (api-docs §3.8).
  Future<Either<Failure, String>> getOAuthUrl({
    required String provider,
    bool connect = false,
  });
}
