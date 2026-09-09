import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';

/// The line a conversation is split on: everything below it is new.
///
/// Drawn once, where the first unread message starts. The count is optional
/// because the marker is placed from `last_read_message_seq` and the number
/// of messages after it is not always known at that point.
class UnreadDivider extends StatelessWidget {
  const UnreadDivider({super.key, required this.label, this.count});

  final String label;

  /// Shown as a pill on the accent side of the label. Non-positive counts are
  /// treated as unknown and draw nothing.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rule = ChatixTheme.of(context).unreadDivider;
    final badge = count;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x2 + 2,
      ),
      child: Row(
        children: [
          Expanded(child: Divider(color: rule)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (badge != null && badge > 0) ...[
                  const SizedBox(width: AppSpacing.x2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x2,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: Divider(color: rule)),
        ],
      ),
    );
  }
}
