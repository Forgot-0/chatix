import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/router/app_router.dart';
import 'package:chatix/core/router/app_routes.dart';

/// The routing guard, tested as a pure function.
///
/// `resolveAuthRedirect` exists as a free function precisely so this file can
/// exercise the whole policy — including the "session died mid-use" path,
/// which is otherwise reachable only by faking an expired refresh token
/// against a live `Dio` — without a widget tree, a `GoRouter`, or a
/// `BuildContext`.
void main() {
  group('isPublicLocation', () {
    test('accepts every screen of the signed-out flow', () {
      for (final location in [
        LoginRoute.location,
        RegisterRoute.location,
        VerifyEmailRoute.location,
        ResetPasswordRoute.location,
        ResetPasswordConfirmRoute.location,
        OAuthCallbackRoute.location,
      ]) {
        expect(
          isPublicLocation(location),
          isTrue,
          reason: '$location must be reachable while signed out',
        );
      }
    });

    test('keeps the query string out of the decision', () {
      // The two places that actually arrive with one: the emailed reset link
      // and the OAuth provider hand-back (api-docs §3.7, §3.8).
      expect(
        isPublicLocation('/reset-password/confirm?token=abc123'),
        isTrue,
      );
      expect(
        isPublicLocation('/oauth-callback?code=xyz&state=nonce'),
        isTrue,
      );
    });

    test('matches whole segments only, never a bare prefix', () {
      // '/loginish' starting with '/login' must not open a private screen.
      expect(isPublicLocation('/loginish'), isFalse);
      expect(isPublicLocation('/registered-users'), isFalse);
    });

    test('rejects the signed-in areas', () {
      for (final location in [
        ChatsRoute.location,
        ProjectsRoute.location,
        NotificationsRoute.location,
        ProfileRoute.location,
        const ChatDetailRoute('7c0b…').location,
        const ProjectDetailRoute(42).location,
        SettingsRoute.location,
      ]) {
        expect(isPublicLocation(location), isFalse, reason: location);
      }
    });
  });

  group('resolveAuthRedirect — session still resolving', () {
    test('holds its decision instead of flashing /login', () {
      // A cold start with a stored token: `GET /users/me/` is in flight and
      // deciding now would bounce a returning user through the login screen
      // and straight back out.
      expect(
        resolveAuthRedirect(
          location: ChatsRoute.location,
          isSessionUnresolved: true,
          isAuthenticated: false,
        ),
        isNull,
      );
    });
  });

  group('resolveAuthRedirect — signed out', () {
    test('sends a private location to /login', () {
      expect(
        resolveAuthRedirect(
          location: ProjectsRoute.location,
          isSessionUnresolved: false,
          isAuthenticated: false,
        ),
        LoginRoute.location,
      );
    });

    test('leaves the public flow alone', () {
      for (final location in [
        LoginRoute.location,
        RegisterRoute.location,
        VerifyEmailRoute.location,
        ResetPasswordConfirmRoute.location,
        OAuthCallbackRoute.location,
      ]) {
        expect(
          resolveAuthRedirect(
            location: location,
            isSessionUnresolved: false,
            isAuthenticated: false,
          ),
          isNull,
          reason: '$location is public and must not redirect',
        );
      }
    });

    test(
      'a session that expires mid-use redirects from anywhere, identically',
      () {
        // This is requirement 4 of the integration: the interceptor signals,
        // `AuthController` flips to signed-out, the router re-runs this
        // callback for whatever location the user was standing on. No screen
        // is involved, so the answer must not depend on which one it was.
        const deepLocations = [
          '/chats/1f0e-uuid',
          '/chats/1f0e-uuid/members',
          '/chats/1f0e-uuid/call',
          '/projects/42',
          '/projects/42/positions/9a7b-uuid',
          '/profiles/17',
          '/notifications',
          '/settings/language',
          '/applications/my',
        ];

        for (final location in deepLocations) {
          expect(
            resolveAuthRedirect(
              location: location,
              isSessionUnresolved: false,
              isAuthenticated: false,
            ),
            LoginRoute.location,
            reason: 'expired session on $location must land on /login',
          );
        }
      },
    );
  });

  group('resolveAuthRedirect — signed in', () {
    test('bounces off /login and /register', () {
      expect(
        resolveAuthRedirect(
          location: LoginRoute.location,
          isSessionUnresolved: false,
          isAuthenticated: true,
        ),
        ChatsRoute.location,
      );
      expect(
        resolveAuthRedirect(
          location: RegisterRoute.location,
          isSessionUnresolved: false,
          isAuthenticated: true,
        ),
        ChatsRoute.location,
      );
    });

    test('still allows verify-email and reset-password', () {
      // An unverified account is signed in and must be able to reach
      // verification; changing a password from inside the app is normal.
      expect(
        resolveAuthRedirect(
          location: VerifyEmailRoute.location,
          isSessionUnresolved: false,
          isAuthenticated: true,
        ),
        isNull,
      );
      expect(
        resolveAuthRedirect(
          location: ResetPasswordRoute.location,
          isSessionUnresolved: false,
          isAuthenticated: true,
        ),
        isNull,
      );
    });

    test('leaves private locations alone', () {
      expect(
        resolveAuthRedirect(
          location: const ChatDetailRoute('abc').location,
          isSessionUnresolved: false,
          isAuthenticated: true,
        ),
        isNull,
      );
    });
  });
}
