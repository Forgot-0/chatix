import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/auth/presentation/utils/password_strength.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The bar under a new-password field.
///
/// Colour alone does not carry the verdict — the word beside it says the
/// same thing — so it survives both themes and a reader who cannot tell the
/// two ends of the scale apart.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);

    final strength = estimatePasswordStrength(password);
    final label = switch (strength) {
      PasswordStrength.empty => null,
      PasswordStrength.weak => l10n.passwordStrengthWeak,
      PasswordStrength.fair => l10n.passwordStrengthFair,
      PasswordStrength.good => l10n.passwordStrengthGood,
      PasswordStrength.strong => l10n.passwordStrengthStrong,
    };

    final colour = switch (strength) {
      PasswordStrength.empty => scheme.outlineVariant,
      PasswordStrength.weak => scheme.error,
      PasswordStrength.fair => scheme.tertiary,
      PasswordStrength.good || PasswordStrength.strong => scheme.primary,
    };

    return Semantics(
      label: l10n.passwordStrengthLabel,
      value: label,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x2),
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.full),
                child: Stack(
                  children: [
                    Container(height: 4, color: scheme.surfaceContainerHighest),
                    LayoutBuilder(
                      builder: (context, constraints) => AnimatedContainer(
                        duration: still
                            ? Duration.zero
                            : const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                        height: 4,
                        width: constraints.maxWidth * strength.fraction,
                        color: colour,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            SizedBox(
              width: 72,
              child: Text(
                label ?? l10n.passwordStrengthLabel,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: label == null ? scheme.onSurfaceVariant : colour,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
