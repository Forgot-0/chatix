import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/auth/presentation/utils/auth_failure_presentation.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The providers `GET /auth/oauth/{provider}/authorize/` knows (api-docs
/// §3.8).
///
/// The glyphs are neutral on purpose. Each provider's own mark comes with
/// usage rules and an official asset pack; until those assets are in the
/// bundle, a stand-in drawn to look like the mark would break the rules it
/// is pretending to follow. So each button carries a plain Material glyph
/// for what the account is — mail, search, code — and the provider's name
/// says the rest.
enum OAuthProvider {
  google('google', Icons.mail_outline_rounded),
  yandex('yandex', Icons.search_rounded),
  github('github', Icons.code_rounded);

  const OAuthProvider(this.id, this.icon);

  /// The `{provider}` path segment.
  final String id;

  final IconData icon;

  /// The provider's name as it is written in [l10n]'s language. Yandex is
  /// the one that changes: it is "Яндекс" in Russian.
  String nameIn(AppLocalizations l10n) => switch (this) {
    OAuthProvider.google => 'Google',
    OAuthProvider.yandex => l10n.oauthProviderYandex,
    OAuthProvider.github => 'GitHub',
  };
}

/// The providers the sign-in and sign-up screens offer.
///
/// None yet. Asking for the provider's URL works, but the way back does
/// not: the provider redirects the browser to the backend's own callback,
/// which answers that browser with the access token and the refresh cookie
/// (api-docs §3.8) — and nothing hands either to the app. How the result
/// should come back (a deep link, a web redirect) depends on the
/// `redirect_uri` the backend is configured with, which the docs leave to
/// be agreed. Until it is, a button here would send people off to sign in
/// somewhere they can never return from. Overridden in tests to draw the
/// section.
final oauthProvidersProvider = Provider<List<OAuthProvider>>((ref) => const []);

/// "or", then one full-width button per provider — under the form's own
/// submit button, and nothing at all when no provider is offered.
class OAuthSection extends ConsumerWidget {
  const OAuthSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(oauthProvidersProvider);
    if (providers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.x5),
        const _OrDivider(),
        for (final provider in providers) ...[
          const SizedBox(height: AppSpacing.x3),
          OAuthButton(provider: provider),
        ],
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
          child: Text(
            AppLocalizations.of(context).authDividerOr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider(color: scheme.outlineVariant)),
      ],
    );
  }
}

/// "Continue with …": asks the backend for the provider's sign-in page and
/// opens it in the browser.
class OAuthButton extends ConsumerStatefulWidget {
  const OAuthButton({required this.provider, super.key});

  final OAuthProvider provider;

  @override
  ConsumerState<OAuthButton> createState() => _OAuthButtonState();
}

class _OAuthButtonState extends ConsumerState<OAuthButton> {
  bool _busy = false;

  Future<void> _open() async {
    setState(() => _busy = true);
    final result = await ref
        .read(getOAuthUrlUseCaseProvider)
        .execute(provider: widget.provider.id);
    if (!mounted) return;
    setState(() => _busy = false);

    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;

    await result.fold(
      // 429 (4 per 5 minutes) and a dead network are the likely ones; both
      // have the reader's own sentence rather than the server's.
      (failure) async => AppUtils.showSnackBar(
        context,
        message: describeAuthFailure(failure, l10n).message,
        backgroundColor: error,
      ),
      (url) async {
        final uri = Uri.tryParse(url);
        final opened =
            uri != null &&
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (opened) return;
        if (!mounted) return;
        AppUtils.showSnackBar(
          context,
          message: l10n.browserOpenFailed,
          backgroundColor: error,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: _busy ? null : _open,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x4,
        ),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: AuthLayout.providerIcon,
            child: _busy
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Icon(widget.provider.icon, size: AuthLayout.providerIcon),
          ),
          Expanded(
            child: Text(
              l10n.continueWith(widget.provider.nameIn(l10n)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Balances the glyph, so the label is centred on the button
          // rather than in what is left of it.
          const SizedBox(width: AuthLayout.providerIcon),
        ],
      ),
    );
  }
}
