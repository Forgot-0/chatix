import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';

/// Google / Yandex / GitHub sign-in buttons (api-docs §3.8). Each button
/// fetches an authorize URL and opens it in the system browser.
///
/// TODO(oauth-callback): after the provider redirects back to
/// `GET /auth/oauth/{provider}/callback/`, the app needs to receive the
/// resulting `AccessTokenResponse` (api-docs §3.8 point 3). That callback
/// currently happens in a browser tab the app doesn't control, and the
/// exact hand-back mechanism (universal/app link vs. an in-app WebView
/// intercepting the redirect) depends on how `redirect_uri` is configured
/// for each provider on the backend — which api-docs §3.8 itself flags as
/// an open question. Do NOT invent a scheme here; this widget intentionally
/// stops at "opened the browser" until the backend team confirms the
/// redirect_uri strategy, at which point this needs either:
///   - a deep link (`app_links`/`uni_links`) route that reads
///     `access_token` from the final redirect and calls
///     `AuthController`/`SecureStorageService`, or
///   - swapping the external browser launch below for an in-app WebView
///     that intercepts the callback URL directly.
class OAuthButtons extends ConsumerWidget {
  const OAuthButtons({super.key});

  static const _providers = [
    (id: 'google', label: 'Google', icon: Icons.g_mobiledata),
    (id: 'yandex', label: 'Yandex', icon: Icons.travel_explore),
    (id: 'github', label: 'GitHub', icon: Icons.code),
  ];

  Future<void> _openProvider(
    BuildContext context,
    WidgetRef ref,
    String provider,
  ) async {
    final result = await ref
        .read(getOAuthUrlUseCaseProvider)
        .execute(provider: provider);

    if (!context.mounted) return;

    result.fold(
      (failure) => AppUtils.showSnackBar(
        context,
        message: failure.message,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
      (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (!context.mounted) return;
          AppUtils.showSnackBar(
            context,
            message: 'Could not open the browser for sign-in',
            backgroundColor: Theme.of(context).colorScheme.error,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _providers.map((provider) {
        return IconButton.outlined(
          tooltip: 'Continue with ${provider.label}',
          onPressed: () => _openProvider(context, ref, provider.id),
          icon: Icon(provider.icon),
        );
      }).toList(),
    );
  }
}
