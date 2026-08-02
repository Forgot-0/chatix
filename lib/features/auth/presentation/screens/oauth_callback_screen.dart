import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';

/// `/oauth-callback` — the landing spot for the provider redirect described in
/// api-docs §3.8, step 3.
///
/// ### Why this exists as a screen and not just a whitelisted string
///
/// [OAuthCallbackRoute] was already listed in `publicRoutePrefixes` so the
/// guard would let a signed-out user through it, but no `GoRoute` was
/// registered for the path. That combination is the worst of both worlds: the
/// redirect passes the auth guard and then lands on the router's 404 page,
/// which reads to the user as "the app is broken" rather than "sign-in didn't
/// finish". Registering a real screen makes the outcome legible and gives the
/// user a way back.
///
/// ### What it deliberately does NOT do
///
/// It does **not** parse `access_token` out of the query string and log the
/// user in. `OAuthButtons` documents why at length: the hand-back mechanism
/// (universal/app link vs. an in-app WebView intercepting `redirect_uri`) is
/// still an open question on the backend side, and api-docs §3.8 flags it as
/// such. Guessing a scheme here would mean writing a token-handling path that
/// nobody can test against the real redirect, and a *wrong* one silently
/// accepting a token from an arbitrary query parameter is a genuine security
/// problem, not just dead code.
///
/// So: this screen is the placeholder the route table needs, and the single
/// place to change when the redirect strategy is settled. Everything else —
/// the public-path whitelist, the route registration, the way back to
/// `/login` — is already correct and won't need touching then.
class OAuthCallbackScreen extends StatelessWidget {
  const OAuthCallbackScreen({super.key, this.error});

  /// The provider's `error` query parameter, when it sent one (api-docs §3.8
  /// mirrors the OAuth2 spec here: `?error=access_denied`).
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userCancelled = error == 'access_denied';

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                userCancelled ? Icons.no_accounts_outlined : Icons.link_off,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                userCancelled
                    ? 'Sign-in was cancelled'
                    : "Couldn't finish signing in",
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                userCancelled
                    ? 'Nothing was changed. You can try again or use your username and password.'
                    : 'Signing in with an external provider is not fully wired up yet. '
                          'Please use your username and password for now.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(LoginRoute.location),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
