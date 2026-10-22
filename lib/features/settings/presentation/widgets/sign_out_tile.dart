import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Signing out, and saying what it costs before it happens.
///
/// The confirmation is not boilerplate: everything this device cached —
/// messages, drafts, downloaded attachments, folders — goes with the
/// session, and there is no undo for a draft. Once the state goes back to
/// signed-out the router's own redirect takes the screen to sign-in; nothing
/// here navigates.
class SignOutTile extends ConsumerStatefulWidget {
  const SignOutTile({super.key});

  @override
  ConsumerState<SignOutTile> createState() => _SignOutTileState();
}

class _SignOutTileState extends ConsumerState<SignOutTile> {
  bool _busy = false;

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: Text(l10n.logoutAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    setState(() => _busy = false);

    if (ref.read(authProvider).hasError) {
      AppSnackbar.failure(context, l10n.logoutFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // A row of the grouped list like every other, set apart by its own
    // card at the bottom and by the danger colour, so it is never the row
    // a thumb lands on by habit.
    return AppGroupedTile(
      icon: Icons.logout_rounded,
      plateColor: AppPlatePalette.danger,
      title: l10n.logout,
      destructive: true,
      subtitle: _busy ? l10n.logoutInProgress : null,
      trailing: _busy
          ? const SizedBox.square(
              dimension: SettingsLayout.rowSpinner,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _busy ? null : _signOut,
    );
  }
}
