import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/auth/presentation/utils/auth_failure_presentation.dart';

/// The error that stays on screen.
///
/// A snackbar is the wrong shape for a sign-in failure: it leaves while the
/// reader is still looking at the field it is about, and it cannot carry the
/// one button that matters — "send the email again" for an account that is
/// real but unconfirmed. This sits above the form instead, and goes away
/// when the next attempt starts.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({
    required this.error,
    this.onAction,
    this.isActionBusy = false,
    this.actionLabel,
    super.key,
  });

  final AuthErrorInfo? error;

  /// Invoked for [AuthErrorInfo.action]; the banner draws no button without
  /// one.
  final VoidCallback? onAction;

  final bool isActionBusy;

  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final info = error;
    if (info == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showAction =
        info.hasAction && onAction != null && actionLabel != null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.x4),
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  info.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          if (showAction)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: isActionBusy ? null : onAction,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onErrorContainer,
                ),
                child: isActionBusy
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onErrorContainer,
                        ),
                      )
                    : Text(actionLabel!),
              ),
            ),
        ],
      ),
    );
  }
}
