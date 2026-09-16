import 'package:flutter/material.dart';

/// One square in a row of quick actions.
class AppQuickAction {
  const AppQuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;

  /// Null greys the square out rather than hiding it, so the row keeps its
  /// shape while, say, the thing it acts on is still loading.
  final VoidCallback? onPressed;
}

/// A handful of equal squares — the two to four things worth doing to
/// whatever is above them.
///
/// Equal widths rather than intrinsic ones: the row reads as a unit, and a
/// short label next to a long one would otherwise make the whole thing look
/// accidental.
class AppQuickActionsRow extends StatelessWidget {
  const AppQuickActionsRow({
    super.key,
    required this.actions,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 12),
  });

  final List<AppQuickAction> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          for (final action in actions)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ActionSquare(action: action),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionSquare extends StatelessWidget {
  const _ActionSquare({required this.action});

  final AppQuickAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = action.onPressed != null;

    final foreground = enabled
        ? scheme.primary
        : scheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onPressed,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: action.label,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action.icon, size: 22, color: foreground),
                const SizedBox(height: 6),
                Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
