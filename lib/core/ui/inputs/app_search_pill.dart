import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// A search box that is really a button.
///
/// It looks like the pill field the contacts tab types into — the same fill,
/// height and magnifier slot — but nothing is typed here: a tap opens the
/// screen where searching happens, with its own field focused. That keeps a
/// list's header a single, always-visible way in without a second search
/// state living inside the list.
class AppSearchPill extends StatelessWidget {
  const AppSearchPill({
    super.key,
    required this.hint,
    required this.onTap,
    this.semanticLabel,
  });

  /// What sits in the box, in the hint colour.
  final String hint;

  final VoidCallback onTap;

  /// Read out instead of [hint] — the longer "what can be found here", which
  /// a short hint leaves to the eye.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: semanticLabel ?? hint,
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: SearchPillSizes.height,
            child: Row(
              children: [
                SizedBox(
                  width: SearchPillSizes.iconSlot,
                  child: Icon(Icons.search, color: scheme.onSurfaceVariant),
                ),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
