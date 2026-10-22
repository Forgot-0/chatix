import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/widgets/app_round_box.dart';

/// One button in a row of quick actions.
class AppQuickAction {
  const AppQuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.anchorKey,
  });

  final IconData icon;
  final String label;

  /// Null greys the button out rather than hiding it, so the row keeps its
  /// shape while, say, the thing it acts on is still loading.
  final VoidCallback? onPressed;

  /// Put on the button, so a menu it opens can be anchored to it.
  final GlobalKey? anchorKey;
}

/// A handful of round buttons with a word under each — the two to four
/// things worth doing to whatever is above them.
///
/// The buttons sit on a raised surface with the glyph in the accent, and the
/// words stay in the text colour: an accent word on a tinted tile read as a
/// label on a label. Every action gets a column of the same width and the
/// row is centred, so the row reads as a unit whether it holds two actions
/// or four, on a phone or across a desktop pane. A pane too narrow for the
/// columns shares out what it has.
class AppQuickActionsRow extends StatelessWidget {
  const AppQuickActionsRow({
    super.key,
    required this.actions,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.x3,
      AppSpacing.x1,
      AppSpacing.x3,
      AppSpacing.x4,
    ),
  });

  final List<AppQuickAction> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final action in actions)
            // A full slot each, however short the word: the gaps between
            // buttons stay equal. Flexible lets a narrow pane take some back.
            Flexible(
              child: SizedBox(
                width: QuickActionSizes.slot,
                child: _ActionButton(key: action.anchorKey, action: action),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({super.key, required this.action});

  final AppQuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = action.onPressed != null;

    final glyph = enabled
        ? scheme.primary
        : scheme.onSurfaceVariant.withValues(alpha: 0.5);
    final word = enabled
        ? scheme.onSurface
        : scheme.onSurfaceVariant.withValues(alpha: 0.7);

    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: action.onPressed,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppRoundBox(
                diameter: QuickActionSizes.button,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    action.icon,
                    size: QuickActionSizes.icon,
                    color: glyph,
                  ),
                ),
              ),
              const SizedBox(height: QuickActionSizes.labelGap),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: word,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
