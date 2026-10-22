import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';
import 'package:chatix/features/auth/presentation/utils/password_strength.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The server's password rules under a new-password field, each ticked off
/// the moment the password meets it.
///
/// The server checks them all at once and refuses a miss with a `422` that
/// names no rule (api-docs §3.2), and the field's own error after a failed
/// submit can only name one. This list shows all five from the first
/// keystroke, so nobody has to submit to find out what is missing.
///
/// A tick, not a colour, carries the verdict; the colour only agrees with it.
class PasswordRulesChecklist extends StatelessWidget {
  const PasswordRulesChecklist({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      container: true,
      label: l10n.passwordRulesTitle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final twoColumns = width >= AuthLayout.ruleColumnsFrom;
          const gap = AppSpacing.x3;
          final half = twoColumns ? (width - gap) / 2 : width;

          return Wrap(
            spacing: gap,
            runSpacing: AuthLayout.ruleRowGap,
            children: [
              for (final rule in PasswordRule.values)
                SizedBox(
                  // The special-character rule lists the characters, and
                  // needs the whole line for them.
                  width: rule == PasswordRule.special ? width : half,
                  child: _RuleLine(
                    label: _labelOf(rule, l10n),
                    met: rule.isMetBy(password),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _labelOf(PasswordRule rule, AppLocalizations l10n) =>
      switch (rule) {
        PasswordRule.length => l10n.passwordRuleLength(
          AuthFieldValidators.passwordMinLength,
          AuthFieldValidators.passwordMaxLength,
        ),
        PasswordRule.uppercase => l10n.passwordRuleUppercase,
        PasswordRule.lowercase => l10n.passwordRuleLowercase,
        PasswordRule.digit => l10n.passwordRuleDigit,
        PasswordRule.special => l10n.passwordRuleSpecial(
          AuthFieldValidators.passwordSpecialCharacters,
        ),
      };
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    final success = ChatixTheme.of(context).success;

    return Semantics(
      label: label,
      value: met ? l10n.passwordRuleMet : l10n.passwordRuleUnmet,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: still ? Duration.zero : AppMotion.fast,
              child: Icon(
                met ? Icons.check_circle : Icons.radio_button_unchecked,
                key: ValueKey(met),
                size: AuthLayout.ruleIcon,
                color: met ? success : scheme.outline,
              ),
            ),
            const SizedBox(width: AuthLayout.ruleIconGap),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: met ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
