import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// A white glyph on a small coloured square — what a settings row leads
/// with, so the row is found by its colour before its words are read.
///
/// Decorative: the row's title already says what the glyph shows.
class AppIconPlate extends StatelessWidget {
  const AppIconPlate({
    super.key,
    required this.icon,
    required this.color,
    this.size = SettingsLayout.plateSize,
    this.iconSize = SettingsLayout.plateIcon,
  });

  final IconData icon;

  /// One of [AppPlatePalette]: the ground stays the same in both themes.
  final Color color;

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(SettingsLayout.plateRadius),
        ),
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, size: iconSize, color: AppPlatePalette.glyph),
        ),
      ),
    );
  }
}

/// Rows on one rounded card with hairlines between them, an optional
/// caption over the card and a note under it — the grouped list settings
/// and profiles are built from.
class AppGroupedSection extends StatelessWidget {
  const AppGroupedSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.dividerIndent = SettingsLayout.rowDividerIndent,
  });

  final List<Widget> children;

  /// A short caption over the card, in the accent.
  final String? header;

  /// What the rows above it mean, small and grey, under the card.
  final String? footer;

  /// Where the hairline between two rows starts: under their titles when
  /// the rows lead with a coloured square, at the card's own padding when
  /// they do not.
  final double dividerIndent;

  /// The raised surface the card is: the near-white paper of the light
  /// theme, the lifted step of the dark one — the pair menus and profile
  /// cards use, so a card reads as the same material everywhere.
  static Color surfaceOf(ThemeData theme) => theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceContainerHigh
      : theme.colorScheme.surfaceContainerLowest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = this.header;
    final footer = this.footer;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SettingsLayout.groupInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Semantics(
              header: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  0,
                  AppSpacing.x4,
                  AppSpacing.x2,
                ),
                child: Text(
                  header,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Material(
            color: surfaceOf(theme),
            borderRadius: BorderRadius.circular(SettingsLayout.groupRadius),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: dividerIndent,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x2,
                AppSpacing.x4,
                0,
              ),
              child: Text(
                footer,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row of an [AppGroupedSection]: a coloured square, a title, and
/// whatever the row ends with — a value, a badge, a switch, or the chevron
/// that says it opens something.
class AppGroupedTile extends StatelessWidget {
  const AppGroupedTile({
    super.key,
    required this.title,
    this.icon,
    this.plateColor,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.destructive = false,
    this.showChevron = true,
    this.enabled = true,
  }) : assert(
         icon == null || plateColor != null,
         'a glyph needs a square to sit on',
       );

  final String title;

  /// The glyph on the coloured square. No square when null.
  final IconData? icon;
  final Color? plateColor;

  final String? subtitle;

  /// The current answer, grey, at the row's end: "English", "2 devices".
  final String? value;

  /// Drawn instead of the chevron: a badge, a switch, a spinner.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// The section open beside the list in a two-pane window.
  final bool selected;

  /// Drawn in the danger colour: signing out.
  final bool destructive;

  /// Whether a row that opens something says so with a chevron.
  final bool showChevron;

  /// A row that cannot be used right now — clearing a cache that is
  /// already empty — is drawn faded and ignores taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final icon = this.icon;
    final subtitle = this.subtitle;
    final value = this.value;
    final trailing =
        this.trailing ??
        (onTap != null && showChevron && !destructive
            ? Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
            : null);

    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SettingsLayout.rowMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x2,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    AppIconPlate(icon: icon, color: plateColor!),
                    const SizedBox(width: SettingsLayout.plateGap),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: !enabled
                                ? theme.disabledColor
                                : destructive
                                ? scheme.error
                                : null,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: SettingsLayout.lineGap,
                            ),
                            child: Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (value != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: SettingsLayout.valueMaxWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.x2),
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.x2),
                    if (enabled)
                      trailing
                    else
                      IconTheme.merge(
                        data: IconThemeData(color: theme.disabledColor),
                        child: trailing,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A grouped row that is a switch: the whole row toggles it, and a screen
/// reader hears one control with its state, not a row and a switch.
class AppGroupedSwitchTile extends StatelessWidget {
  const AppGroupedSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.icon,
    this.plateColor,
    this.subtitle,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final Color? plateColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;

    return MergeSemantics(
      child: AppGroupedTile(
        title: title,
        icon: icon,
        plateColor: plateColor,
        subtitle: subtitle,
        onTap: onChanged == null ? null : () => onChanged(!value),
        // The whole row is the target, so the switch need not pad itself
        // out to one — which would make every switch row taller than the
        // rows around it.
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
