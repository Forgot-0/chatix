import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/auth/app_lock_providers.dart';
import 'package:chatix/core/auth/biometric_providers.dart';
import 'package:chatix/core/auth/biometric_service.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The switch that puts ChatiX behind a fingerprint when it is reopened.
///
/// Turning it **on** asks for a scan first. Not ceremony: a switch that
/// trusted the setting alone could lock someone out of an app whose
/// biometrics do not actually work on this device, and the only way back
/// would be to sign out. The scan proves the lock can be opened before it is
/// ever closed.
///
/// The tile stays visible with no biometrics enrolled, disabled and saying
/// why — the alternative is a setting that silently does not exist, which
/// reads as a bug.
class BiometricUnlockTile extends ConsumerStatefulWidget {
  const BiometricUnlockTile({super.key});

  @override
  ConsumerState<BiometricUnlockTile> createState() =>
      _BiometricUnlockTileState();
}

class _BiometricUnlockTileState extends ConsumerState<BiometricUnlockTile> {
  bool _busy = false;

  Future<void> _toggle(bool enable) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(biometricUnlockEnabledProvider.notifier);

    if (!enable) {
      await controller.setEnabled(false);
      return;
    }

    setState(() => _busy = true);

    final result = await ref
        .read(biometricAuthControllerProvider.notifier)
        .authenticate(reason: l10n.biometricUnlockReason);

    if (!mounted) return;
    setState(() => _busy = false);

    if (result != BiometricResult.success) {
      AppSnackbar.quiet(
        context,
        switch (result) {
          BiometricResult.lockedOut => l10n.biometricUnlockLockedOut,
          BiometricResult.notEnrolled ||
          BiometricResult.notAvailable => l10n.biometricUnlockNotEnrolled,
          _ => l10n.biometricUnlockEnableFailed,
        },
      );
      return;
    }

    await controller.setEnabled(true);
    // `appLockProvider` starts locked whenever the setting is on; the scan
    // that just passed is the one this lock wanted.
    ref.read(appLockProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(biometricUnlockEnabledProvider);
    final available = ref
        .watch(biometricsAvailableProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);

    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint),
      title: Text(l10n.biometricUnlockTitle),
      subtitle: Text(
        available
            ? l10n.biometricUnlockSubtitle
            : l10n.biometricUnlockUnavailable,
      ),
      value: enabled && available,
      onChanged: (!available || _busy) ? null : _toggle,
    );
  }
}
