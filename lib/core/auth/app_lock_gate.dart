import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/auth/app_lock_providers.dart';
import 'package:chatix/core/auth/biometric_service.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Holds the app behind a biometric prompt when it is reopened.
///
/// Mounted above the router rather than inside a route, so no navigation —
/// a notification tap, a deep link, a restored back stack — can arrive
/// behind it. It does nothing at all unless somebody is signed in and has
/// switched the lock on in settings.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _prompting = false;

  /// One automatic prompt per lock, so a refused scan leaves the button
  /// rather than looping the system dialog.
  bool _autoPrompted = false;

  BiometricResult? _lastResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        controller.noteLeftForeground();
      case AppLifecycleState.resumed:
        controller.noteReturnedToForeground();
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _unlock() async {
    if (_prompting) return;
    setState(() => _prompting = true);

    final reason = AppLocalizations.of(context).biometricUnlockReason;
    final result = await ref
        .read(appLockProvider.notifier)
        .authenticate(reason: reason);

    if (!mounted) return;
    setState(() {
      _prompting = false;
      _lastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;
    final isLocked = ref.watch(appLockProvider);

    if (!isAuthenticated || !isLocked) {
      _autoPrompted = false;
      _lastResult = null;
      return widget.child;
    }

    if (!_autoPrompted) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _unlock();
      });
    }

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: _LockScreen(
            isPrompting: _prompting,
            lastResult: _lastResult,
            onUnlock: _unlock,
          ),
        ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.isPrompting,
    required this.lastResult,
    required this.onUnlock,
  });

  final bool isPrompting;
  final BiometricResult? lastResult;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final problem = switch (lastResult) {
      null || BiometricResult.success || BiometricResult.cancelled => null,
      BiometricResult.lockedOut => l10n.biometricUnlockLockedOut,
      BiometricResult.notEnrolled ||
      BiometricResult.notAvailable => l10n.biometricUnlockNotEnrolled,
      BiometricResult.failed || BiometricResult.error =>
        l10n.biometricUnlockFailed,
    };

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56, color: scheme.primary),
                const SizedBox(height: AppSpacing.x5),
                Text(
                  l10n.biometricUnlockLockedTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  l10n.biometricUnlockLockedBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (problem != null) ...[
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    problem,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.x6),
                FilledButton.icon(
                  onPressed: isPrompting ? null : onUnlock,
                  icon: isPrompting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint),
                  label: Text(l10n.biometricUnlockAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
