import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/router/app_router.dart';
import 'package:chatix/core/router/app_routes.dart';

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
      expect(isPublicLocation('/loginish'), isFalse);
      expect(isPublicLocation('/registered-users'), isFalse);
    });

    test('rejects the signed-in areas', () {
      for (final location in [
        ChatsRoute.location,
        NotificationsRoute.location,
        ProfileRoute.location,
        const ChatDetailRoute('7c0b…').location,
        SettingsRoute.location,
      ]) {
        expect(isPublicLocation(location), isFalse, reason: location);
      }
    });
  });

  group('resolveAuthRedirect — session still resolving', () {
    test('holds its decision instead of flashing /login', () {
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
          location: NotificationsRoute.location,
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
        const deepLocations = [
          '/chats/1f0e-uuid',
          '/chats/1f0e-uuid/members',
          '/chats/1f0e-uuid/call',
          '/profiles/17',
          '/notifications',
          '/settings/language',
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
