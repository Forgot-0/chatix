import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// The raised surface a profile's cards sit on: the near-white paper of the
/// light theme, the lifted step of the dark one — the same pair menus use,
/// so a card reads as the same material wherever it appears.
Color profileCardColor(ThemeData theme) => theme.brightness == Brightness.dark
    ? theme.colorScheme.surfaceContainerHigh
    : theme.colorScheme.surfaceContainerLowest;

/// A rounded card of rows with hairlines between them — the facts about a
/// person, or the rows that only belong on one's own profile.
class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: profileCardColor(theme),
      borderRadius: BorderRadius.circular(ProfileLayout.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: AppSpacing.x4,
                color: theme.colorScheme.outlineVariant,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One fact: what it says on top, and what it is underneath — small and
/// grey, the way a contact card reads ("@ada" over "Username").
///
/// No leading glyph: the caption already says what the value is, and a
/// column of icons down the left made a short profile look like a form.
class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    super.key,
    required this.value,
    required this.caption,
    this.valueColor,
    this.maxLines = 1,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  final String value;
  final String caption;

  /// The accent for something that opens when tapped — a link.
  final Color? valueColor;

  /// Null lets the value run to as many lines as it has: a bio.
  final int? maxLines;

  final VoidCallback? onTap;

  /// Also what a right click does, so the same thing is in reach with a
  /// mouse.
  final VoidCallback? onLongPress;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ProfileLayout.infoRowMinHeight,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.x4,
            AppSpacing.x2,
            trailing == null ? AppSpacing.x4 : AppSpacing.x1,
            AppSpacing.x2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: maxLines,
                      overflow: maxLines == null
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: valueColor ?? scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: ProfileLayout.infoLineGap),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
