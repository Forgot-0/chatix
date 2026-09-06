import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';

class OAuthCallbackScreen extends StatelessWidget {
  const OAuthCallbackScreen({super.key, this.error});

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
