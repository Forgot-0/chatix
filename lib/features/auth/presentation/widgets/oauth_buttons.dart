import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';

const bool oauthSignInEnabled = false;

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
        if (uri == null ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
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
    if (!oauthSignInEnabled) return const SizedBox.shrink();

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
