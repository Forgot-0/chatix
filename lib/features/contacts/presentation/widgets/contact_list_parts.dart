import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/widgets/app_round_box.dart';

/// An accent row at the top of a list of people — "Add contact", "New
/// group" — that lines up with the people below it: the same height, an
/// icon in a tinted circle where a face would be.
class ContactEntryRow extends StatelessWidget {
  const ContactEntryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chatix = ChatixTheme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        // The same height as a person's row, so the list reads as one.
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x1 + chatix.density.listRowPadding,
        ),
        child: Row(
          children: [
            AppRoundBox(
              diameter: ContactsLayout.actionBadge,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: ContactsLayout.actionIcon,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
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

/// The letter over a run of people whose names start with it.
class ContactLetterHeading extends StatelessWidget {
  const ContactLetterHeading({super.key, required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      header: true,
      child: Container(
        height: ContactsLayout.letterHeight,
        alignment: AlignmentDirectional.bottomStart,
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.x4,
          bottom: AppSpacing.x1,
        ),
        child: Text(
          letter,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
