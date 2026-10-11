import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// The label that turns a flat list of settings tiles into groups.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x6,
          AppSpacing.x4,
          AppSpacing.x2,
        ),
        child: Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
