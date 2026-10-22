import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/auth/presentation/utils/auth_failure_presentation.dart';
import 'package:chatix/features/auth/presentation/widgets/oauth_provider_marks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The providers `GET /auth/oauth/{provider}/authorize/` knows (api-docs
/// §3.8).
enum OAuthProvider {
  google('google'),
  yandex('yandex'),
  github('github');

  const OAuthProvider(this.id);

  /// The `{provider}` path segment.
  final String id;

  /// What the button says.
  ///
  /// Yandex's is fixed: its rules forbid changing the text of its button,
  /// and it publishes that text in Russian and English only. Google's and
  /// GitHub's follow one template, matched to it.
  String labelIn(AppLocalizations l10n) => switch (this) {
    OAuthProvider.google => l10n.oauthSignInWith('Google'),
    OAuthProvider.yandex => l10n.oauthYandexSignIn,
    OAuthProvider.github => l10n.oauthSignInWith('GitHub'),
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

/// How one provider's button is painted on a light or a dark page — the
/// provider's own colours, from [OAuthButtonSpec].
@immutable
class OAuthButtonLook {
  const OAuthButtonLook({
    required this.fill,
    required this.text,
    required this.stroke,
    required this.gap,
  });

  /// Google: white with a grey hairline inside, or near-black with a
  /// lighter one. GitHub sets no rules and wears the same.
  factory OAuthButtonLook.neutral({required bool dark, required double gap}) =>
      OAuthButtonLook(
        fill: dark ? OAuthButtonSpec.darkFill : OAuthButtonSpec.lightFill,
        text: dark ? OAuthButtonSpec.darkText : OAuthButtonSpec.lightText,
        stroke: BorderSide(
          color: dark
              ? OAuthButtonSpec.darkStroke
              : OAuthButtonSpec.lightStroke,
          width: OAuthButtonSpec.googleStroke,
        ),
        gap: gap,
      );

  /// Yandex ID: the "additional" version — meant to stand beside other
  /// services' buttons — on a light page, the "main" one on a dark page.
  factory OAuthButtonLook.yandex({required bool dark}) => dark
      ? const OAuthButtonLook(
          fill: OAuthButtonSpec.yandexInk,
          text: OAuthButtonSpec.yandexPaper,
          stroke: BorderSide.none,
          gap: OAuthButtonSpec.yandexGap,
        )
      : const OAuthButtonLook(
          fill: OAuthButtonSpec.yandexPaper,
          text: OAuthButtonSpec.yandexInk,
          stroke: BorderSide(
            color: OAuthButtonSpec.yandexInk,
            width: OAuthButtonSpec.yandexStroke,
            // Yandex draws its stroke on the outline, half in, half out.
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
          gap: OAuthButtonSpec.yandexGap,
        );

  factory OAuthButtonLook.of(OAuthProvider provider, {required bool dark}) =>
      switch (provider) {
        OAuthProvider.google => OAuthButtonLook.neutral(
          dark: dark,
          gap: OAuthButtonSpec.googleGap,
        ),
        OAuthProvider.yandex => OAuthButtonLook.yandex(dark: dark),
        OAuthProvider.github => OAuthButtonLook.neutral(
          dark: dark,
          gap: OAuthButtonSpec.githubGap,
        ),
      };

  final Color fill;
  final Color text;
  final BorderSide stroke;

  /// Between the mark and the words.
  final double gap;
}

/// "Sign in with …": asks the backend for the provider's sign-in page and
/// opens it in the browser.
///
/// Every provider's button has the same shape — a full-width pill, the mark
/// and the words centred together, as Yandex lays its own out — so the
/// three read as one set, while each keeps the colours, stroke and mark its
/// owner requires.
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

  Widget _mark(bool dark) => switch (widget.provider) {
    OAuthProvider.google => GoogleMark(dark: dark),
    OAuthProvider.yandex => YandexMark(
      cyrillic: Localizations.localeOf(context).languageCode == 'ru',
    ),
    OAuthProvider.github => GitHubMark(dark: dark),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final look = OAuthButtonLook.of(widget.provider, dark: dark);
    final label = widget.provider.labelIn(l10n);
    final shape = StadiumBorder(side: look.stroke);

    // One node: "Sign in with Google, button". The words are read from
    // here, the marks say nothing, and the tap the ink well registers
    // lands on this same node.
    return Semantics(
      button: true,
      enabled: !_busy,
      label: label,
      child: Material(
        color: look.fill,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : _open,
          customBorder: shape,
          child: SizedBox(
            height: OAuthButtonSpec.height,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OAuthButtonSpec.sidePadding,
              ),
              child: Center(
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_busy)
                        SizedBox.square(
                          dimension: OAuthButtonSpec.googleMark,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: look.text,
                          ),
                        )
                      else
                        _mark(dark),
                      SizedBox(width: look.gap),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: look.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
